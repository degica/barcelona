namespace :bcn do
  def user_input(desc, default_value: nil)
    default_desc = default_value.nil? ? "" : "[#{default_value}]"
    print "#{desc} #{default_desc}: "
    value = STDIN.gets.chomp
    value.blank? ? default_value : value
  end

  task :prepare_self_deploy do
    require 'dotenv'

    ENV["RAILS_ENV"] = 'self_hosting'
    Dotenv.load('.env.self_hosting')
    Rake::Task["db:setup"].invoke
  end

  desc "Bootstrap Barcelona to the specified ECS cluster(local)"
  task :bootstrap_local => ["bcn:prepare_self_deploy", :environment] do
    access_key_id       = user_input("AWS Access Key ID", default_value: ENV["AWS_ACCESS_KEY_ID"])
    secret_key          = user_input("AWS Secret Access Key", default_value: ENV["AWS_SECRET_ACCESS_KEY"])
    district_name       = user_input("District(ECS cluster) name", default_value: "default")
    database_url        = user_input("Database URL", default_value: ENV["BARCELONA_DATABASE_URL"] || "postgres://user:password@your.domain:5432/dbname")
    dockercfg = JSON.load(dockercfg) if dockercfg.present?

    ENV["AWS_REGION"] = 'ap-northeast-1'
    ENV["AWS_ACCESS_KEY_ID"] = access_key_id
    ENV["AWS_SECRET_ACCESS_KEY"] = secret_key

    district = District.create!(
      name:   district_name,
      vpc_id: vpc_id,
      public_elb_security_group:  public_elb_sg,
      private_elb_security_group: private_elb_sg,
      instance_security_group: instance_sg,
      ecs_service_role:        ecs_service_role,
      ecs_instance_role:       ecs_instance_role,
      private_hosted_zone_id:  private_hosted_zone_id,
      s3_bucket_name:          s3_bucket_name,
      dockercfg: dockercfg,
      aws_access_key_id: access_key_id,
      aws_secret_access_key: secret_access_key
    )

    if user_input("Do you want to launch a new container instance? [y/N]") =~ /^[Yy]?$/
      district.launch_instances(count: 1, instance_type: "t2.micro")

      puts ""
      puts "Created new ECS cluster with 1 container instance."
      puts "Press enter when you confirm the container instance is running and registered to the cluster."
      STDIN.gets
    end

    app = district.apps.create!(
      name: "barcelona",
      image_name: docker_image_name,
      image_tag: "latest"
    )

    oneoff = app.oneoffs.create(
      env_vars: {
        "AWS_REGION"                 => ENV["AWS_REGION"],
        "AWS_ACCESS_KEY_ID"          => ENV["AWS_ACCESS_KEY_ID"],
        "AWS_SECRET_ACCESS_KEY"      => ENV["AWS_SECRET_ACCESS_KEY"],
        "RAILS_ENV"                  => "production",
        "DATABASE_URL"               => database_url,
        "DISTRICT_NAME"              => district_name,
        "VPC_ID"                     => vpc_id,
        "PUBLIC_ELB_SECURITY_GROUP"  => public_elb_sg,
        "PRIVATE_ELB_SECURITY_GROUP" => private_elb_sg,
        "INSTANCE_SECURITY_GROUP"    => instance_sg,
        "ECS_SERVICE_ROLE"           => ecs_service_role,
        "ECS_INSTANCE_ROLE"          => ecs_instance_role,
        "PRIVATE_HOSTED_ZONE_ID"     => private_hosted_zone_id,
        "S3_BUCKET_NAME"             => s3_bucket_name,
        "DOCKER_IMAGE_NAME"          => docker_image_name,
        "DOCKERCFG"                  => district.dockercfg.to_json
      },
      command: "rake bcn:self_deploy_remote"
    )

    puts "Provisioning barcelona service. This may take several minutes."
    oneoff.run!(sync: true)
  end

  desc "Deploy Barcelona to the specified ECS cluster(remote)"
  task :self_deploy_remote => :environment do
    Rake::Task["db:setup"].invoke
    Delayed::Worker.delay_jobs = false
    district = District.create!(
      name:   ENV["DISTRICT_NAME"],
      vpc_id: ENV["VPC_ID"],
      public_elb_security_group: ENV["PUBLIC_ELB_SECURITY_GROUP"],
      private_elb_security_group: ENV["PRIVATE_ELB_SECURITY_GROUP"],
      instance_security_group: ENV["INSTANCE_SECURITY_GROUP"],
      ecs_service_role: ENV["ECS_SERVICE_ROLE"],
      ecs_instance_role: ENV["ECS_INSTANCE_ROLE"],
      private_hosted_zone_id: ENV["PRIVATE_HOSTED_ZONE_ID"],
      s3_bucket_name: ENV["S3_BUCKET_NAME"],
      dockercfg: JSON.load(ENV["DOCKERCFG"]),
      aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    )

    ENV["ENCRYPTION_KEY"] = SecureRandom.hex(64)

    district.apps.create!(
      name: "barcelona",
      image_name: ENV["DOCKER_IMAGE_NAME"],
      image_tag: "latest",
      before_deploy: "rake db:migrate",
      env_vars_attributes: [
        {key: "AWS_REGION", value: ENV["AWS_REGION"]},
        {key: "AWS_ACCESS_KEY_ID",     value: ENV["AWS_ACCESS_KEY_ID"]},
        {key: "AWS_SECRET_ACCESS_KEY", value: ENV["AWS_SECRET_ACCESS_KEY"]},
        {key: "RAILS_ENV",     value: "production"},
        {key: "DATABASE_URL",  value: ENV["DATABASE_URL"]},
        {key: "SECRET_KEY_BASE", value: SecureRandom.hex(64)},
        {key: "ENCRYPTION_KEY", value: ENV["ENCRYPTION_KEY"]}
      ],
      services_attributes: [
        {
          name: "web",
          cpu: 256,
          memory: 256,
          public: true,
          command: "rails s -p 3000 -b 0.0.0.0",
          port_mappings_attributes: [
            {lb_port: 80, container_port: 3000}
          ]
        },
        {
          name: "worker",
          cpu: 128,
          memory: 256,
          command: "rake jobs:work"
        }
      ]
    )
  end
end
