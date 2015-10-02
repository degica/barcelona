require 'dotenv'

namespace :bcn do
  def user_input(desc, default_value: nil)
    default_desc = default_value.nil? ? "" : "[#{default_value}]"
    print "#{desc} #{default_desc}: "
    value = STDIN.gets.chomp
    value.blank? ? default_value : value
  end

  task :prepare_self_deploy do
    ENV["RAILS_ENV"] = 'self_hosting'
    Dotenv.load('.env.self_hosting')
    Rake::Task["db:setup"].invoke
  end

  desc "Deploy Barcelona to the specified ECS cluster(local)"
  task :self_deploy_local => ["bcn:prepare_self_deploy", :environment] do
    access_key_id       = user_input("AWS Access Key ID", default_value: ENV["AWS_ACCESS_KEY_ID"])
    secret_key          = user_input("AWS Secret Access Key", default_value: ENV["AWS_SECRET_ACCESS_KEY"])
    district_name       = user_input("District(ECS cluster) name", default_value: "default")
    vpc_id              = user_input("VPC ID", default_value: ENV["VPC_ID"])
    public_elb_sg       = user_input("Public ELB Security Group", default_value: ENV["PUBLIC_ELB_SECURITY_GROUP"])
    private_elb_sg      = user_input("Private ELB Security Group", default_value: ENV["PRIVATE_ELB_SECURITY_GROUP"])
    instance_sg         = user_input("Container Instance Security Group", default_value: ENV["INSTANCE_SECURITY_GROUP"])
    ecs_service_role    = user_input("ECS Service Role", default_value: "ecsServiceRole")
    ecs_instance_role   = user_input("ECS Instance Role", default_value: "ecsInstanceRole")
    private_hosted_zone_id = user_input("Route53 Private Hosted Zone ID", default_value: ENV["PRIVATE_HOSTED_ZONE_ID"])
    s3_bucket_name      = user_input("S3 Bucket Name", default_value: ENV["S3_BUCKET_NAME"])
    database_url        = user_input("Database URL", default_value: ENV["BARCELONA_DATABASE_URL"] || "postgres://user:password@your.domain:5432/dbname")
    docker_image_name   = user_input("Barcelona Docker Image Name", default_value: "degica/barcelona")
    dockercfg           = user_input("Dockercfg JSON", default_value: ENV["DOCKERCFG"])
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
      dockercfg: dockercfg
    )

#    district.launch_instances(count: 1)

    puts ""
    puts "Created new ECS cluster with 1 container instance."
    puts "Press enter when you confirm the container instance is running and registered to the cluster."
    STDIN.gets

    heritage = district.heritages.create!(
      name: "barcelona",
      container_name: docker_image_name,
      container_tag: "self-hosting"
    )

    oneoff = heritage.oneoffs.create(
      env_vars: [
        {name: "AWS_REGION",                 value: ENV["AWS_REGION"]},
        {name: "AWS_ACCESS_KEY_ID",          value: ENV["AWS_ACCESS_KEY_ID"]},
        {name: "AWS_SECRET_ACCESS_KEY",      value: ENV["AWS_SECRET_ACCESS_KEY"]},
        {name: "RAILS_ENV",                  value: "production"},
        {name: "DATABASE_URL",               value: database_url},
        {name: "DISTRICT_NAME",              value: district_name},
        {name: "VPC_ID",                     value: vpc_id},
        {name: "PUBLIC_ELB_SECURITY_GROUP",  value: public_elb_sg},
        {name: "PRIVATE_ELB_SECURITY_GROUP", value: private_elb_sg},
        {name: "INSTANCE_SECURITY_GROUP",    value: instance_sg},
        {name: "ECS_SERVICE_ROLE",           value: ecs_service_role},
        {name: "ECS_INSTANCE_ROLE",          value: ecs_instance_role},
        {name: "PRIVATE_HOSTED_ZONE_ID",     value: private_hosted_zone_id},
        {name: "S3_BUCKET_NAME",             value: s3_bucket_name},
        {name: "DOCKER_IMAGE_NAME",          value: docker_image_name},
      ],
      command: ["rake", "bcn:self_deploy_remote"]
    )
    oneoff.run!(sync: true)
  end

  desc "Deploy Barcelona to the specified ECS cluster(remote)"
  task :self_deploy_remote => :environment do
    Rake::Task["db:setup"].invoke
    district = District.create!(
      name:   ENV["DISTRICT_NAME"],
      vpc_id: ENV["VPC_ID"],
      public_elb_security_group: ENV["PUBLIC_ELB_SECURITY_GROUP"],
      private_elb_security_group: ENV["PRIVATE_ELB_SECURITY_GROUP"],
      instance_security_group: ENV["INSTANCE_SECURITY_GROUP"],
      ecs_service_role: ENV["ECS_SERVICE_ROLE"],
      ecs_instance_role: ENV["ECS_INSTANCE_ROLE"],
      private_hosted_zone_id: ENV["PRIVATE_HOSTED_ZONE_ID"],
      s3_bucket_name: ENV["S3_BUCKET_NAME"]
    )

    ENV["ENCRYPTION_KEY"] = SecureRandom.hex(64)

    district.heritages.create!(
      sync: true,
      name: "barcelona",
      container_name: ENV["DOCKER_IMAGE_NAME"],
      container_tag: "self-hosting",
      before_deploy: ["rake", "db:migrate"],
      env_vars_attributes: [
        {key: "AWS_REGION", value: ENV["AWS_REGION"]},
        {key: "AWS_ACCESS_KEY_ID",     value: ENV["AWS_ACCESS_KEY_ID"]},
        {key: "AWS_SECRET_ACCESS_KEY", value: ENV["AWS_SECRET_ACCESS_KEY"]},
        {key: "RAILS_ENV",     value: "production"},
        {key: "DATABASE_URL",  value: ENV["DATABASE_URL"]},
        {key: "SECRET_KEY_BASE", value: SecureRandom.hex(64)},
        {key: "ENCRYPTION_KEY", value: ENV["ENCRYPTION_KEY"]},
      ],
      services_attributes: [
        {
          name: "web",
          cpu: 128,
          memory: 128,
          public: true,
          command: ["rails", "s", "-p", "3000", "-b", "0.0.0.0"],
          port_mappings_attributes: [
            {lb_port: 80, container_port: 3000}
          ]
        },
        {
          name: "worker",
          cpu: 128,
          memory: 128,
          command: ["rake", "jobs:work"]
        }
      ]
    )
  end
end
