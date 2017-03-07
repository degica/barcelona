class PluginSerializer < ActiveModel::Serializer
  attributes :name
  attribute :plugin_attributes, key: :attributes
end
