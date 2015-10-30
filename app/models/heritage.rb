class Heritage < ActiveRecord::Base
  has_many :services, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :oneoffs, dependent: :destroy
  has_many :events, dependent: :destroy
  belongs_to :district

  validates :name, presence: true, uniqueness: true
  validates :district, presence: true

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

  private

  def update_services(without_before_deploy)
    return if image_path.nil?
    DeployRunnerJob.perform_later self, without_before_deploy: without_before_deploy
  end
end
