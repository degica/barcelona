class ContainerInstance
  attr_accessor :section, :options

  def aws
    section.aws
  end

  def district
    section.district
  end

  def initialize(section, options)
    @section = section
    @options = options
  end

  def launch
    resp = aws.ec2.run_instances(
      image_id: 'ami-6e920b6e', # amzn-ami-2015.09.a-amazon-ecs-optimized
      min_count: 1,
      max_count: 1,
      user_data: instance_user_data,
      instance_type: options[:instance_type],
      network_interfaces: [
        {
          groups: [section.instance_security_group].compact,
          subnet_id: section.subnets.sample.subnet_id,
          device_index: 0,
          associate_public_ip_address: section.public?
        }
      ],
      iam_instance_profile: {
        name: section.ecs_instance_role
      }
    )
  end

  def instance_user_data
    user_data = <<EOS
#!/bin/bash
yum install -y aws-cli

#{associate_address_user_data}

aws s3 cp s3://#{section.s3_bucket_name}/#{section.cluster_name}/ecs.config /etc/ecs/ecs.config

sed -i 's/^#\\s%wheel\\s*ALL=(ALL)\\s*NOPASSWD:\\sALL$/%wheel\\tALL=(ALL)\\tNOPASSWD:\\tALL/g' /etc/sudoers

curl -o ./docker https://get.docker.com/builds/Linux/x86_64/docker-1.8.3
mv ./docker /usr/bin/docker
chmod 755 /usr/bin/docker

service docker restart

PRIVATE_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

service rsyslog stop
rm -rf /dev/log
docker run -d --restart=always --name="logger" -p 514:514 -v /dev:/dev -e "LE_TOKEN=#{section.logentries_token}" -e "SYSLOG_HOSTNAME=$PRIVATE_IP" k2nr/rsyslog-logentries

aws s3 cp s3://#{section.s3_bucket_name}/#{district.name}/users ./users
echo >> ./users
while IFS=, read name pub
do
  docker run --rm -v /etc:/etc -v /home:/home -e "USER_NAME=$name" -e "USER_PUBLIC_KEY=$pub" -e 'USER_DOCKERCFG=#{section.dockercfg.to_json}' -e USER_GROUPS="docker,wheel" k2nr/docker-user-manager
done < ./users
rm ./users
start ecs
EOS
    Base64.encode64(user_data)
  end

  def associate_address_user_data
    if options[:eip_allocation_id]
    <<EOS
INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 associate-address --region ap-northeast-1 --instance-id $INSTANCE_ID --allocation-id #{options[:eip_allocation_id]}
EOS
    else
      ""
    end
  end
end
