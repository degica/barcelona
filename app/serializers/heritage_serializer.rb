class HeritageSerializer < ActiveModel::Serializer
  attributes :name, :image_name, :image_tag, :env_vars, :before_deploy, :slack_url, :token

  has_many :services
  belongs_to :district

  def env_vars
    # Heritage#env_vars don't include env vars which are added by plugins
    # as plugins add env vars to task_definition directly and those are not
    # stored in DB'
    task_definition = object.base_task_definition('_')
    Hash[task_definition[:environment].map { |env| [env[:name], env[:value]] }]
  end
end
