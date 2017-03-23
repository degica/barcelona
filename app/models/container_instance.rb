class ContainerInstance
  attr_accessor :district

  def initialize(district)
    @district = district
  end

  def user_data
    user_data = InstanceUserData.new
    user_data.packages += ["aws-cli", "jq", "aws-cfn-bootstrap", "awslogs"]
    user_data.run_commands += [
      "set -e",
      # Embed SHA2 hash dockercfg so that instance replacement happens when dockercfg is updated
      "# #{Digest::SHA256.hexdigest(district.dockercfg.to_s)}",

      # Setup swap
      "MEMSIZE=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`",
      "if [ $MEMSIZE -lt 2097152 ]; then",
      "  SIZE=$((MEMSIZE * 2))k",
      "elif [ $MEMSIZE -lt 8388608 ]; then",
      "  SIZE=${MEMSIZE}k",
      "else",
      "  SIZE=8388608k",
      "fi",
      "fallocate -l $SIZE /swap.img && mkswap /swap.img && chmod 600 /swap.img && swapon /swap.img",

      "AWS_REGION=#{district.region}",
      "aws configure set s3.signature_version s3v4",
      "aws s3 cp s3://#{district.s3_bucket_name}/#{district.name}/ecs.config /etc/ecs/ecs.config",
      "chmod 600 /etc/ecs/ecs.config",

      # Configure sshd
      'printf "\nTrustedUserCAKeys /etc/ssh/ssh_ca_key.pub\n" >> /etc/ssh/sshd_config',
      'sed -i -e "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config',
      "service sshd restart",

      "chkconfig --add barcelona",
      "chkconfig barcelona on",
      "service barcelona start",

      # Configure AWS CloudWatch Logs
      "ec2_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)",
      'sed -i -e "s/{ec2_id}/$ec2_id/g" /etc/awslogs/awslogs.conf',
      'sed -i -e "s/us-east-1/'+district.region+'/g" /etc/awslogs/awscli.conf',
      "service awslogs start",

      # Install AWS Inspector agent
      "curl https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install | bash"
    ]

    user_data.add_file("/etc/ssh/ssh_ca_key.pub", "root:root", "644", district.ssh_format_ca_public_key)
    user_data.add_file("/etc/ssh/exec-interactive-oneoff.sh", "root:root", "755", <<~EOS)
      #!/bin/bash
      read oneoff_id command <<< $SSH_ORIGINAL_COMMAND
      container_id=$(docker ps -q -f "label=com.barcelona.oneoff-id=$oneoff_id")
      [[ -n $container_id ]] && docker exec --detach-keys="ctrl-\\\\,\\\\" -it $container_id $command
    EOS

    user_data.add_file("/etc/init.d/barcelona", "root:root", "755", <<EOS)
#!/bin/bash
# chkconfig: 2345 96 04
# description: Barcelona

set -e

stop() {
  AWS_REGION=#{district.region}
  ecs_cluster=`curl http://localhost:51678/v1/metadata | jq -r .Cluster`
  container_instance_arn=`curl http://localhost:51678/v1/metadata | jq -r .ContainerInstanceArn | cut -d / -f2`

  aws ecs deregister-container-instance --region $AWS_REGION --cluster $ecs_cluster --container-instance $container_instance_arn --force
  sleep 60

  docker stop -t 90 $(docker ps -q)
}

case "$1" in
  start)
    touch /var/lock/subsys/barcelona
    ;;
  stop)
    stop
    rm /var/lock/subsys/barcelona
    ;;
  *) exit 2;;
esac
EOS

    # CloudWatch Logs configurations
    # See http://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_cloudwatch_logs.html
    user_data.add_file("/etc/awslogs/awslogs.conf", "root:root", "644", <<~EOS)
      [general]
      state_file = /var/lib/awslogs/agent-state

      [/var/log/dmesg]
      file = /var/log/dmesg
      log_group_name = #{district.instance_log_group_name}
      log_stream_name = {ec2_id}/var/log/dmesg

      [/var/log/messages]
      file = /var/log/messages
      log_group_name = #{district.instance_log_group_name}
      log_stream_name = {ec2_id}/var/log/messages
      datetime_format = %b %d %H:%M:%S

      [/var/log/secure]
      file = /var/log/secure
      log_group_name = #{district.instance_log_group_name}
      log_stream_name = {ec2_id}/var/log/secure
      datetime_format = %b %d %H:%M:%S

      [/var/log/docker]
      file = /var/log/docker
      log_group_name = #{district.instance_log_group_name}
      log_stream_name = {ec2_id}/var/log/docker
      datetime_format = %Y-%m-%dT%H:%M:%S.%f

      [/var/log/ecs/ecs-init.log]
      file = /var/log/ecs/ecs-init.log.*
      log_group_name = #{district.instance_log_group_name}
      log_stream_name = {ec2_id}/var/log/ecs/ecs-init.log
      datetime_format = %Y-%m-%dT%H:%M:%SZ

      [/var/log/ecs/ecs-agent.log]
      file = /var/log/ecs/ecs-agent.log.*
      log_group_name = #{district.instance_log_group_name}
      log_stream_name = {ec2_id}/var/log/ecs/ecs-agent.log
      datetime_format = %Y-%m-%dT%H:%M:%SZ

      [/var/log/ecs/audit.log]
      file = /var/log/ecs/audit.log.*
      log_group_name = #{district.instance_log_group_name}
      log_stream_name = {ec2_id}/var/log/ecs/audit.log
      datetime_format = %Y-%m-%dT%H:%M:%SZ
    EOS

    user_data = district.hook_plugins(:container_instance_user_data, self, user_data)
  end
end
