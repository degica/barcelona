class InstanceUserData
  attr_accessor :files, :boot_commands, :run_commands, :packages, :users

  def self.load_or_initialize(base64 = nil)
    if base64.nil?
      InstanceUserData.new
    else
      InstanceUserData.load(base64)
    end
  end

  def self.load(base64)
    yml = YAML.load(Base64.decode64(base64))
    instance = self.new
    instance.files = yml["write_files"] || []
    instance.boot_commands = yml["bootcmd"] || []
    instance.run_commands = yml["runcmd"] || []
    instance.packages = yml["packages"] || []
    instance.users = yml["users"] || []
    instance
  end

  def initialize
    @files = []
    @boot_commands = []
    @run_commands = []
    @users = []
    @packages = []
  end

  def build
    user_data = {
      "repo_update" => true,
      "repo_upgrade" => "all",
      "packages" => packages.uniq,
      "write_files" => files,
      "bootcmd" => boot_commands,
      "runcmd" => run_commands,
      "users" => users
    }.reject{ |_, v| v.blank? }
    raw_user_data = "#cloud-config\n" << YAML.dump(user_data)
    Base64.encode64(raw_user_data)
  end

  def empty?
    [files, boot_commands, run_commands, users, packages].all?(&:empty?)
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
