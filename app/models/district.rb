class District < ActiveRecord::Base
  include AwsAccessible

  attr_accessor :dockercfg

  before_save :update_ecs_config
  before_create :create_ecs_cluster
  after_destroy :delete_ecs_cluster

  has_many :heritages, dependent: :destroy
  has_many :users_districts
  has_many :users, through: :users_districts

  validates :name, presence: true
  validates :vpc_id, presence: true
  validates :private_hosted_zone_id, presence: true

  def to_param
    name
  end

  def subnets(network)
    @subnets ||= Aws::EC2::Client.new.describe_subnets(
      filters: [
        {name: "vpc-id", values: [vpc_id]},
        {name: 'tag:Network', values: [network]}
      ]
    ).subnets
  end

  def launch_instances(count: 1)
    ec2.run_instances(
      image_id: 'ami-6e920b6e', # amzn-ami-2015.09.a-amazon-ecs-optimized
      min_count: count,
      max_count: count,
      key_name: 'kkajihiro',
      security_group_ids: [instance_security_group].compact,
      user_data: instance_user_data,
      instance_type: 't2.micro',
      subnet_id: subnets("Private").sample.subnet_id,
      iam_instance_profile: {
        name: ecs_instance_role
      }
    )
  end

  def container_instances
    arns = ecs.list_container_instances(cluster: name).container_instance_arns
    container_instances = ecs.describe_container_instances(cluster: name,
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

    ec2_instances = ec2.describe_instances(
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
    s3.put_object(bucket: s3_bucket_name,
                  key: "#{name}/users",
                  body: users_body,
                  server_side_encryption: "AES256")
    UpdateUserTask.new(self, user).run
  end

  private

  def update_ecs_config
    return if dockercfg.blank?
    s3.put_object(bucket: s3_bucket_name,
                  key: "#{name}/ecs.config",
                  body: ecs_config,
                  server_side_encryption: "AES256")
  end

  def create_ecs_cluster
    ecs.create_cluster(cluster_name: name)
  end

  def instance_user_data
    user_data = <<EOS
#!/bin/bash
yum install -y aws-cli
aws s3 cp s3://#{s3_bucket_name}/#{name}/ecs.config /etc/ecs/ecs.config

cat <<EOF > /etc/sysconfig/docker
OPTIONS="--log-driver=syslog --log-opt syslog-address=tcp://127.0.0.1:514"
EOF
service docker restart

PRIVATE_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
docker run -d --restart=always --name="logger" -p 514:514 -v /var/log:/var/log -e "LE_TOKEN=#{logentries_token}" -e "SYSLOG_HOSTNAME=$PRIVATE_IP" k2nr/rsyslog-logentries

aws s3 cp s3://#{s3_bucket_name}/#{name}/users ./users
echo >> ./users
while IFS=, read name pub
do
  docker run --rm -v /etc:/etc -v /home:/home -e "USER_NAME=$name" -e "USER_PUBLIC_KEY=$pub" k2nr/docker-user-manager
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
    ecs.delete_cluster(cluster: name)
  end
end
