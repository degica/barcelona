FactoryBot.define do
  factory :plugin do
    name { "datadog" }
    plugin_attributes { { api_key: 'datadogapikey' } }
  end
end
