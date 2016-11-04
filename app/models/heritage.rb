class Heritage < ActiveRecord::Base
  has_many :services, inverse_of: :heritage, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :oneoffs, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :releases, -> { order 'version DESC' }, dependent: :destroy, inverse_of: :heritage
  belongs_to :district, inverse_of: :heritages

  validates :name,
            presence: true,
            uniqueness: true,
            immutable: true,
            format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\z/ }
  validates :district, presence: true

  before_validation do |heritage|
    heritage.regenerate_token if heritage.token.blank?
  end

  accepts_nested_attributes_for :services, allow_destroy: true
  accepts_nested_attributes_for :env_vars

  after_initialize do |heritage|
    heritage.version ||= 1
  end

  def to_param
    name
  end

  def describe_services
    district.aws.ecs.describe_services(
      cluster: district.name,
      services: services.map(&:service_name)
    ).services
  end

  def image_path
    return nil if image_name.blank?
    tag = image_tag || 'latest'
    "#{image_name}:#{tag}"
  end

  def save_and_deploy!(without_before_deploy: false, description: "")
    save!
    release = releases.create!(description: description)
    update_services(release, without_before_deploy)
    release
  end

  def regenerate_token
    self.token = SecureRandom.uuid
  end

  def base_task_definition(task_name, with_environment: true)
    base = district.base_task_definition.merge(
      name: task_name,
      cpu: 256,
      memory: 256,
      essential: true,
      image: image_path
    )
    if with_environment
      base[:environment] += env_vars.where(secret: false).map { |e| {name: e.key, value: e.value} }
    end

    district.hook_plugins(:heritage_task_definition, self, base)
  end

  private

  def update_services(release, without_before_deploy)
    return if image_path.nil?
    DeployRunnerJob.perform_later(
      self,
      without_before_deploy: without_before_deploy,
      description: release.description
    )
  end
end
