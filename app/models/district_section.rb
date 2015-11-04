class DistrictSection
  attr_accessor :name, :district

  delegate :aws,
           :vpc_id,
           :s3_bucket_name,
           :private_hosted_zone_id,
           :ecs_instance_role,
           :instance_security_group,
           :users,
           :dockercfg,
           :logentries_token,
           to: :district

  def initialize(name, district)
    @name = name
    @district = district
  end

  def subnets
    @subnets ||= aws.ec2.describe_subnets(
      filters: [
        {name: "vpc-id", values: [vpc_id]},
        {name: 'tag:Network', values: [name.to_s.camelize]}
      ]
    ).subnets
  end

  def launch_instances(count: 1, instance_type:, associate_eip: false)
    if associate_eip
      available_eips = district.elastic_ips.available.to_a
      raise "Elastic IP not available" if available_eips.count < count
    end

    resp = aws.ec2.run_instances(
      image_id: 'ami-6e920b6e', # amzn-ami-2015.09.a-amazon-ecs-optimized
      min_count: count,
      max_count: count,
      security_group_ids: [instance_security_group].compact,
      user_data: instance_user_data,
      instance_type: instance_type,
      subnet_id: subnets.sample.subnet_id,
      iam_instance_profile: {
        name: ecs_instance_role
      }
    )
    if associate_eip
      instance_ids = resp.instances.map(&:instance_id)
      instance_ids.each_with_index do |instance_id, index|
        available_eips[index].associate(instance_id)
      end
    end
  end

  def container_instances
    arns = aws.ecs.list_container_instances(cluster: cluster_name).container_instance_arns
    return [] if arns.blank?
    container_instances = aws.ecs
                          .describe_container_instances(cluster: cluster_name, container_instances: arns)
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
    district.put_users_file
    UpdateUserTask.new(self, user).run
  end

  def cluster_name
    case name
    when :private
      district.name
    when :public
      "#{district.name}-public"
    end
  end

  def update_ecs_config
    return if dockercfg.blank?
    aws.s3.put_object(bucket: s3_bucket_name,
                  key: "#{cluster_name}/ecs.config",
                  body: ecs_config,
                  server_side_encryption: "AES256")
  end

  def create_ecs_cluster
    aws.ecs.create_cluster(cluster_name: cluster_name)
  end

  def delete_ecs_cluster
    aws.ecs.delete_cluster(cluster: cluster_name)
  end

  private

  def instance_user_data
    user_data = <<EOS
#!/bin/bash
yum install -y aws-cli
aws s3 cp s3://#{s3_bucket_name}/#{cluster_name}/ecs.config /etc/ecs/ecs.config

sed -i 's/^#\\s%wheel\\s*ALL=(ALL)\\s*NOPASSWD:\\sALL$/%wheel\\tALL=(ALL)\\tNOPASSWD:\\tALL/g' /etc/sudoers

curl -o ./docker https://get.docker.com/builds/Linux/x86_64/docker-1.8.3
mv ./docker /usr/bin/docker
chmod 755 /usr/bin/docker

service docker restart

PRIVATE_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

service rsyslog stop
rm -rf /dev/log
docker run -d --restart=always --name="logger" -p 514:514 -v /dev:/dev -e "LE_TOKEN=#{logentries_token}" -e "SYSLOG_HOSTNAME=$PRIVATE_IP" k2nr/rsyslog-logentries

aws s3 cp s3://#{s3_bucket_name}/#{district.name}/users ./users
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
end
