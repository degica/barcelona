class HeritageSerializer < ActiveModel::Serializer
  attributes :name, :image_name, :image_tag, :env_vars, :before_deploy,
             :token, :version, :scheduled_tasks, :environment

  has_many :services
  belongs_to :district

  def env_vars
    Hash[object.env_vars.map do |e|
      [e.key, e.value.presence || "<secret>"]
    end]
  end

  def environment
    object.environments.
      map { |e| e.slice(:name, :value, :value_from) }.
      sort_by { |e| e[:name] }
  end
end
