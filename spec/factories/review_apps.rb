FactoryBot.define do
  factory :review_app do
    sequence(:subject) { |n| "subject-#{n}" }
    retention_hours { 24 }
    image_name { "quay.io/degica/image" }
    image_tag { "v2" }
    before_deploy { "before_deploy_command" }
    environment { [] }
    service_params {
      {
        service_type: "web",
        cpu: 128,
        memory: 256,
        command: "nginx",
      }
    }

    association :review_group
  end
end
