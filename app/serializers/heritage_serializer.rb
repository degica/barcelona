class HeritageSerializer < ActiveModel::Serializer
  attributes :name, :image_name, :image_tag, :env_vars, :before_deploy,
             :slack_url, :token, :version, :aws_actions, :scheduled_tasks

  has_many :services
  belongs_to :district

  def env_vars
    Hash[object.env_vars.map do |e|
      [e.key, e.value.presence || "<secret>"]
    end]
  end
end
