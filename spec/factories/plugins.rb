FactoryBot.define do
  factory :plugin do
    name "logentries"
    plugin_attributes(token: 'logentriestoken')
  end
end
