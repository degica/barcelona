class ReviewApp < ApplicationRecord
  belongs_to :heritage, dependent: :destroy, autosave: true
  belongs_to :review_group

  attr_accessor :image_name, :image_tag, :services, :before_deploy, :environment
  validates :subject, :image_name, :image_tag, :retention, :services, presence: true
  validates :subject, format: {
    with: /\A[a-z0-9][a-z0-9(-|_)]*[a-z0-9]\z/,
    message: 'must only contain lowercase characters, numbers and hyphens, and can only start and end with a letter or a number'
  }

  validates :retention, numericality: {greater_than: 0, less_than: 24 * 3600 * 30}

  before_validation :build_heritage
  before_validation do
    self.retention ||= 24 * 3600
  end
  after_save :deploy

  def build_heritage
    web_service = services.find{ |s| s[:service_type].to_s == "web" }
    web_service[:listeners] = [{}] if web_service[:listeners].blank?
    web_service[:listeners][0][:endpoint] = review_group.endpoint.name
    web_service[:listeners][0][:rule_priority] = rule_priority_from_subject
    web_service[:listeners][0][:rule_conditions] ||= []
    web_service[:listeners][0][:rule_conditions] << {type: "host-header", value: domain}

    params = {
      name: "review-#{slug_digest}",
      image_name: image_name,
      image_tag: image_tag,
      before_deploy: before_deploy,
      environment: computed_environment,
      services: services
    }

    self.heritage = BuildHeritage.new(params, district: review_group.district).execute
  end

  def deploy
    touch
    self.heritage.deploy!(description: "ReviewApp for #{subject}")
    CleanupReviewAppJob.set(wait: retention).perform_later(self)
  end

  def domain
    "#{sanitized_subject}.#{review_group.base_domain}"
  end

  def rule_priority_from_subject
    (slug_digest.to_i(16) % 50000) + 1
  end

  def slug
    review_group.name + "---" + sanitized_subject
  end

  def slug_digest
    Digest::SHA256.hexdigest(slug)[0...8]
  end

  def to_param
    sanitized_subject
  end

  def expired?(now = Time.current)
    updated_at < (now - retention.seconds)
  end

  def computed_environment
    environment + [
      {name: "BARCELONA_REVIEWAPP_DOMAIN", value: domain}
    ]
  end

  # replace underscores and downcase - not valid as subdomain
  def sanitized_subject
    subject.downcase.gsub('_', '-')
  end
end
