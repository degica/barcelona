class District < ActiveRecord::Base
  include EncryptAttribute

  before_save :update_ecs_config
  before_create :create_ecs_cluster
  after_destroy :delete_ecs_cluster

  has_many :heritages, dependent: :destroy
  has_many :users_districts, dependent: :destroy
  has_many :users, through: :users_districts

  validates :name, presence: true
  validates :vpc_id, presence: true
  validates :private_hosted_zone_id, presence: true
  validates :aws_access_key_id, presence: true
  validates :aws_secret_access_key, presence: true

  serialize :dockercfg, JSON

  encrypted_attribute :aws_access_key_id, secret_key: ENV['ENCRYPTION_KEY']
  encrypted_attribute :aws_secret_access_key, secret_key: ENV['ENCRYPTION_KEY']

  def aws
    @aws ||= AwsAccessor.new(aws_access_key_id, aws_secret_access_key)
  end

  def to_param
    name
  end

  def subnets(network)
    @subnets ||= aws.ec2.describe_subnets(
      filters: [
        {name: "vpc-id", values: [vpc_id]},
        {name: 'tag:Network', values: [network]}
      ]
    ).subnets
  end

  def launch_instances(count: 1, instance_type:)
    aws.ec2.run_instances(
      image_id: 'ami-6e920b6e', # amzn-ami-2015.09.a-amazon-ecs-optimized
      min_count: count,
      max_count: count,
      key_name: 'kkajihiro',
      security_group_ids: [instance_security_group].compact,
      user_data: instance_user_data,
      instance_type: instance_type,
      subnet_id: subnets("Private").sample.subnet_id,
      iam_instance_profile: {
        name: ecs_instance_role
      }
    )
  end

  def container_instances
    arns = aws.ecs.list_container_instances(cluster: name).container_instance_arns
    container_instances = aws.ecs.describe_container_instances(cluster: name,
                                                           container_instances: arns)
                          .container_instances
    instances = {}
    container_instances.each do |ci|
      instance = {
        status: ci.status,
        container_instance_arn: ci.container_instance_arn,
        remaining_resources: ci.remaining_resources,
        registered_resources: ci.registered_resources,
        running_tasks_count: ci.running_tasks_count,
        pending_tasks_count: ci.pending_tasks_count
      }
      instances[ci.ec2_instance_id] = instance
    end

    ec2_instances = aws.ec2.describe_instances(
      instance_ids: container_instances.map(&:ec2_instance_id)
    ).reservations.map(&:instances).flatten

    ec2_instances.each do |ins|
      instances[ins.instance_id].merge!(
        private_ip_address: ins.private_ip_address
      )
    end

    instances.map { |ec2_id, ins| ins.merge(ec2_instance_id: ec2_id) }
  end

  def update_instance_user_account(user)
    aws.s3.put_object(bucket: s3_bucket_name,
                  key: "#{name}/users",
                  body: users_body,
                  server_side_encryption: "AES256")
    UpdateUserTask.new(self, user).run
  end

  private

  def update_ecs_config
    return if dockercfg.blank?
    aws.s3.put_object(bucket: s3_bucket_name,
                  key: "#{name}/ecs.config",
                  body: ecs_config,
                  server_side_encryption: "AES256")
  end

  def create_ecs_cluster
    aws.ecs.create_cluster(cluster_name: name)
  end

  def instance_user_data
    user_data = <<EOS
#!/bin/bash
yum install -y aws-cli
aws s3 cp s3://#{s3_bucket_name}/#{name}/ecs.config /etc/ecs/ecs.config

sed -i 's/^#\\s%wheel\\s*ALL=(ALL)\\s*NOPASSWD:\\sALL$/%wheel\\tALL=(ALL)\\tNOPASSWD:\\tALL/g' /etc/sudoers

curl -o ./docker https://get.docker.com/builds/Linux/x86_64/docker-1.8.3
mv ./docker /usr/bin/docker
chmod 755 /usr/bin/docker

service docker restart

PRIVATE_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

service rsyslog stop
rm -rf /dev/log
docker run -d --restart=always --name="logger" -p 514:514 -v /dev:/dev -e "LE_TOKEN=#{logentries_token}" -e "SYSLOG_HOSTNAME=$PRIVATE_IP" k2nr/rsyslog-logentries

aws s3 cp s3://#{s3_bucket_name}/#{name}/users ./users
echo >> ./users
while IFS=, read name pub
do
  docker run --rm -v /etc:/etc -v /home:/home -e "USER_NAME=$name" -e "USER_PUBLIC_KEY=$pub" -e 'USER_DOCKERCFG=#{dockercfg.to_json}' -e USER_GROUPS="docker,wheel" k2nr/docker-user-manager
done < ./users
rm ./users
start ecs
EOS
    Base64.encode64(user_data)
  end

  def ecs_config
    {
      "ECS_CLUSTER" => name,
      "ECS_ENGINE_AUTH_TYPE" => "dockercfg",
      "ECS_ENGINE_AUTH_DATA" => dockercfg.to_json,
      "ECS_AVAILABLE_LOGGING_DRIVERS" => '["json-file", "syslog", "fluentd"]'
    }.map {|k, v| "#{k}=#{v}"}.join("\n")
  end

  def users_body
    users.map{|u| "#{u.name},#{u.public_key}"}.join("\n")
  end

  def delete_ecs_cluster
    aws.ecs.delete_cluster(cluster: name)
  end
end
