class HeritageSerializer < ActiveModel::Serializer
  attributes :name, :container_name, :container_tag, :env_vars

  has_many :services
  belongs_to :district

  def env_vars
    Hash[object.env_vars.map { |env| [env.key, env.value] }]
  end
end
