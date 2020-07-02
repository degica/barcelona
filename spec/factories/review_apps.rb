FactoryBot.define do
  factory :review_app do
    sequence(:subject) { |n| "subject-#{n}" }
    retention { 24 * 3600 }
    image_name { "quay.io/degica/image" }
    image_tag { "v2" }
    before_deploy { "before_deploy_command" }
    environment { [] }
    services {
      [{
        name: "web",
        service_type: "web",
        cpu: 128,
        memory: 256,
        command: "nginx",
      }]
    }

    association :review_group
  end
end
