class Heritage < ActiveRecord::Base
  has_many :services, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :oneoffs, dependent: :destroy
  has_many :events, dependent: :destroy
  belongs_to :district

  validates :name, presence: true, uniqueness: true
  validates :district, presence: true
  validates :section_name, presence: true, inclusion: { in: %w[public private] }

  before_validation do |heritage|
    heritage.section_name ||= 'private'
  end

  accepts_nested_attributes_for :services
  accepts_nested_attributes_for :env_vars

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

  def save_and_deploy!(without_before_deploy: false)
    save!
    update_services(without_before_deploy)
  end

  def section
    district.sections[section_name.to_sym]
  end

  def base_task_definition(task_name)
    {
      name: task_name,
      cpu: 256,
      memory: 256,
      essential: true,
      image: image_path,
      environment: env_vars.map { |e| {name: e.key, value: e.value} },
      log_configuration: {
        log_driver: "syslog",
        options: {
          "syslog-address" => "tcp://127.0.0.1:514",
          # TODO: Since docker 1.9.0 `syslog-tag` has been marked as deprecated and
          # the option name changed to `tag`
          # `syslog-tag` option will be removed at docker 1.11.0
          "syslog-tag" => task_name
        }
      }
    }
  end

  private

  def update_services(without_before_deploy)
    return if image_path.nil?
    DeployRunnerJob.perform_later self, without_before_deploy: without_before_deploy
  end
end
