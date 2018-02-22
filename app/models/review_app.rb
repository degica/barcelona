class ReviewApp < ApplicationRecord
  belongs_to :heritage, dependent: :destroy

  validates :subject, :group, :base_domain, presence: true

  attr_accessor :retention_hours

  def create_heritage(heritage_params, district)
    heritage_params[:name] = "review-#{subject_id}"
    listener = heritage_params[:services][0][:listeners][0]
    listener[:rule_conditions] = [{type: "host-header",
                                   value: domain}]

    listener[:rule_priority] = 100 + (self.id % 10000)
    params = heritage_params.permit!
    @heritage = BuildHeritage.new(params, district: district).execute
    self.heritage = @heritage
    @heritage.save_and_deploy!(without_before_deploy: true, description: "ReviewApp for #{subject}")
    CleanupReviewAppJob.set(wait: retention_hours.hours).perform_later(self)
    nil
  end

  def subject_id
    Digest::SHA2.hexdigest(subject).first(6)
  end

  def domain
    "#{subject_id}.#{base_domain}"
  end
end
