class HeritageSerializer < ActiveModel::Serializer
  attributes :name, :image_name, :image_tag, :env_vars, :before_deploy, :slack_url, :section_name, :token

  has_many :services
  belongs_to :district

  def env_vars
    Hash[object.env_vars.map { |env| [env.key, env.value] }]
  end
end
