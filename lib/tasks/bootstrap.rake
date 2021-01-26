namespace :bcn do
  def wait_cf_stack(executor)
    while true
      sleep 10
      case executor.stack_status
      when "CREATE_COMPLETE"
        puts
        break
      when /_IN_PROGRESS/
        print "."
      else
        raise "Unexpected CF stack status"
      end
    end
  end

  desc "Deploy Barcelona to the specified ECS cluster(local)"
  task :bootstrap => ["db:setup", :environment] do
    access_key_id = ENV["AWS_ACCESS_KEY_ID"]
    secret_key    = ENV["AWS_SECRET_ACCESS_KEY"]
    region        = ENV["AWS_REGION"]
    gh_org        = ENV["GITHUB_ORGANIZATION"]
    acm_cert_arn  = ENV["ACM_CERT_ARN"]
    district_name = ENV["DISTRICT_NAME"]

    ENV["ENCRYPTION_KEY"] = "encryptionkey"

    # Create District and network stack
    district = District.find_or_initialize_by(name: district_name)
    if district.id.nil?
      district.region = region
      ApplyDistrict.new(district).create!(access_key_id, secret_key)

      print "Creating Network Stack"
      wait_cf_stack(district.stack_executor)
    end

    # Create RDS
    if ENV["BOOTSTRAP_DATABASE_URL"].nil?
      stack = Barcelona::Network::RDSStack.new("barcelona-db", district,
                                               engine: :postgresql,
                                               db_user: 'barcelona',
                                               db_name: "barcelona")
      executor = CloudFormation::Executor.new(stack, district)
      db_password = SecureRandom.hex(16).hex.to_s(36).rjust(25, '0')
      parameters = [
        {
          parameter_key: "DBPassword",
          parameter_value: db_password
        }
      ]
      executor.create(parameters: parameters)
      print "Creating Barcelona Database"
      wait_cf_stack(executor)

      db_endpoint = executor.outputs["DBEndpoint"]
      ENV["BOOTSTRAP_DATABASE_URL"] = "postgresql://#{stack.db_user}:#{db_password}@#{db_endpoint}:5432/#{stack.db_name}"
    end

    # Run oneoff task that runs inside the VPC and creates barcelona service and endpoint
    heritage = district.heritages.new(
      name: "barcelona-bootstrap",
      image_name: "quay.io/degica/barcelona",
      image_tag: "master"
    )
    heritage.env_vars.build(key: "DATABASE_URL", value: ENV["BOOTSTRAP_DATABASE_URL"], secret: true)
    heritage.env_vars.build(key: "DISABLE_DATABASE_ENVIRONMENT_CHECK", value: "1", secret: false)
    heritage.env_vars.build(key: "AWS_REGION", value: region, secret: false)
    heritage.env_vars.build(key: "AWS_ACCESS_KEY_ID", value: access_key_id, secret: false)
    heritage.env_vars.build(key: "AWS_SECRET_ACCESS_KEY", value: secret_key, secret: true)
    heritage.env_vars.build(key: "RAILS_ENV", value: "production", secret: false)
    heritage.env_vars.build(key: "RAILS_LOG_TO_STDOUT", value: "true", secret: false)
    heritage.env_vars.build(key: "DISTRICT_NAME", value: district_name, secret: false)
    heritage.env_vars.build(key: "S3_BUCKET_NAME", value: district.s3_bucket_name, secret: false)
    heritage.env_vars.build(key: "CIDR_BLOCK", value: district.cidr_block, secret: false)
    heritage.env_vars.build(key: "SSH_CA_PUBLIC_KEY", value: district.ssh_ca_public_key, secret: false)
    if acm_cert_arn
      heritage.env_vars.build(key: "ACM_CERT_ARN", value: acm_cert_arn, secret: false)
    end
    heritage.env_vars.build(key: "GITHUB_ORGANIZATION", value: gh_org, secret: false)
    heritage.save!

    print "Provisioning Barcelona service"
    wait_cf_stack(heritage.cf_executor)

    oneoff = heritage.oneoffs.create!(command: "rake bcn:bootstrap:remote")
    oneoff.run

    while !oneoff.stopped?
      sleep 10
      print "."
    end
    puts

    if oneoff.exit_code != 0
      raise "Provisioning failed."
    end

    endpoint_stack = CloudFormation::Stack.new("endpoint-barcelona")
    dns_name = CloudFormation::Executor.new(endpoint_stack, district).outputs["DNSName"]

    heritage.destroy!

    puts
    puts <<-EOS
Barcelona Bootstrap Completed!
Endpoint: #{dns_name}

Set your DNS record to point to the above endpoint and run the following Barcelona client command
$ bcn login https://<your barcelona domain> <GitHub Token>
EOS
  end

  namespace :bootstrap do
    desc "Deploy Barcelona to the specified ECS cluster(remote)"
    task :remote => :environment do
      ENV["ENCRYPTION_KEY"] = SecureRandom.hex(64)

      Rake::Task["db:setup"].invoke
      Delayed::Worker.delay_jobs = false

      district = District.create!(
        name: ENV["DISTRICT_NAME"],
        s3_bucket_name: ENV["S3_BUCKET_NAME"],
        region: ENV["AWS_REGION"],
        cidr_block: ENV["CIDR_BLOCK"],
        aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
        ssh_ca_public_key: ENV["SSH_CA_PUBLIC_KEY"]
      )

      endpoint = district.endpoints.create!(name: "barcelona", public: true, certificate_id: ENV["ACM_CERT_ARN"])
      wait_cf_stack(endpoint.cf_executor)

      heritage = district.heritages.new(
        name: "barcelona",
        image_name: "quay.io/degica/barcelona",
        image_tag: "master",
        before_deploy: "rake db:migrate",
        env_vars_attributes: [
          {key: "RAILS_ENV", value: "production", secret: false},
          {key: "RAILS_LOG_TO_STDOUT", value: "true", secret: false},
          {key: "GITHUB_ORGANIZATION", value: ENV['GITHUB_ORGANIZATION'], secret: false},
          {key: "DATABASE_URL",  value: ENV["DATABASE_URL"], secret: true},
          {key: "SECRET_KEY_BASE", value: SecureRandom.hex(64), secret: true},
          {key: "ENCRYPTION_KEY", value: ENV["ENCRYPTION_KEY"], secret: true}
        ],
        services_attributes: [
          {
            name: "web",
            cpu: 64,
            memory: 256,
            service_type: "web",
            command: "puma -C config/puma.rb",
            force_ssl: true,
            listeners_attributes: [
              {
                endpoint: endpoint,
                health_check_path: "/health_check"
              }
            ]
          },
          {
            name: "worker",
            cpu: 64,
            memory: 256,
            command: "rake jobs:work"
          }
        ]
      )
      heritage.save!

      # Sleep 30 seconds to wait for heritage stack to be created
      sleep 30

      iam = Aws::IAM::Client.new(region: ENV["AWS_REGION"])
      iam.put_role_policy(
        role_name: heritage.task_role_id.split('/').last,
        policy_name: "assume-role",
        policy_document: {"Version" => "2012-10-17", "Statement" => [{"Effect" => "Allow", "Action" => ["sts:AssumeRole"], "Resource" => ["*"]}]}.to_json
      )

      heritage.save_and_deploy!(without_before_deploy: true, description: "Create")
      finalizer = heritage.oneoffs.create!(command: "rake bcn:bootstrap:finalize")
      finalizer.run!
    end

    desc "Finalize bootstrap"
    task :finalize => :environment do
      district = District.find_by(name: "default")
      ReplaceCredsWithRole.new(district).run!
    end
  end
end
