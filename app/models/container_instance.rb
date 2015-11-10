class ContainerInstance
  class UserData
    attr_accessor :files, :boot_commands, :run_commands, :packages, :users

    def initialize
      @files = []
      @boot_commands = []
      @run_commands = []
      @users = []
      @packages = ["aws-cli"]
    end

    def build
      user_data = {
        "repo_update" => true,
        "repo_upgrade" => "all",
        "packages" => packages,
        "write_files" => files,
        "bootcmd" => boot_commands,
        "runcmd" => run_commands,
        "users" => users
      }.reject{ |k, v| v.blank? }
      raw_user_data = "#cloud-config\n" << YAML.dump(user_data)
      Base64.encode64(raw_user_data)
    end

    def add_file(path, owner, permissions, content)
      @files << {
        "path" => path,
        "owner" => owner,
        "permissions" => permissions,
        "content" => content
      }
    end

    def add_user(name, authorized_keys: [], groups: [])
      @users << {
        "name" => name,
        "ssh-authorized-keys" => authorized_keys,
        "groups" => groups.join(',')
      }
    end
  end

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
    user_data = UserData.new
    if options[:eip_allocation_id]
      user_data.run_commands += [
        "INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`",
        "aws ec2 associate-address --region ap-northeast-1 --instance-id $INSTANCE_ID --allocation-id #{options[:eip_allocation_id]}"
      ]
    end
    user_data.run_commands += [
      "aws s3 cp s3://#{section.s3_bucket_name}/#{section.cluster_name}/ecs.config /etc/ecs/ecs.config",
      "sed -i 's/^#\\s%wheel\\s*ALL=(ALL)\\s*NOPASSWD:\\sALL$/%wheel\\tALL=(ALL)\\tNOPASSWD:\\tALL/g' /etc/sudoers",
      "curl -o ./docker https://get.docker.com/builds/Linux/x86_64/docker-1.8.3",
      "mv ./docker /usr/bin/docker",
      "chmod 755 /usr/bin/docker",
      "service docker restart",
      "start ecs"
    ]

    district.users.each do |user|
      user_data.add_user(user.name, authorized_keys: [user.public_key], groups: user.instance_groups)
    end

    user_data = district.hook_plugins(:container_instance_user_data, self, user_data)

    user_data.build
  end
end
