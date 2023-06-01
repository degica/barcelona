require 'tempfile'
require 'timeout'

class SignSSHKey
  attr_accessor :user, :district, :ca_key

  def initialize(user, district, ca_key)
    @user = user
    @district = district
    @ca_key = ca_key
  end

  def sign(identity: nil, force_command: nil, no_touch_required:nil, validity: "+10m", principals: %w[ec2-user hopper])
    raise ArgumentError if user.public_key.blank? || ca_key.blank?

    identity ||= user.name

    secret_key_path = Dir::Tmpname.create("sk_fifo", nil) do |tmpname, _, _|
      File.mkfifo(tmpname, 0o600)
    end

    public_key_file = Tempfile.new('pubkey')
    public_key_file.write(user.public_key)
    public_key_file.close

    serial_number = SecureRandom.random_number(2**32)

    comm = [
      "ssh-keygen",
      "-s", secret_key_path,
      "-I", identity,
      "-n", principals.join(','),
      "-V", validity,
      "-z", serial_number
    ]
    comm += ["-O", "force-command='#{force_command}'"] if force_command
    comm += ["-O", "no-touch-required='#{no_touch_required}'"] if no_touch_required
    comm += [public_key_file.path]

    pid = spawn(comm.join(' '), err: '/dev/null', out: '/dev/null')
    Timeout.timeout(1) do
      File.open(secret_key_path, 'w') { |f| f.write(ca_key) }
      Process.wait(pid)
    end
    Event.new(district).notify(message: "Signed public key for user #{user.name} with identity #{identity} serial_number: #{serial_number}")

    File.read(public_key_file.path + "-cert.pub")
  rescue Timeout::Error
    Process.kill("KILL", pid)
  ensure
    public_key_file.delete if public_key_file.present?
    File.delete(secret_key_path) if secret_key_path.present?
  end
end
