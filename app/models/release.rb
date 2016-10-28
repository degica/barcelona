class Release < ActiveRecord::Base
  belongs_to :heritage, required: true, inverse_of: :releases
  delegate :district, to: :heritage

  serialize :heritage_params, JSON

  before_create do |release|
    release.heritage_params = export_heritage
    release.version = heritage.releases.count + 1
  end

  def rollback
    heritage.attributes = heritage_params
    heritage.save_and_deploy!(
      without_before_deploy: true,
      description: "Rolled back to version #{version}"
    )
  end

  def export_heritage
    exported = heritage.attributes.slice("image_name", "image_tag")
    exported["services_attributes"] = heritage.services.map do |service|
      service.attributes.slice(
        "id",
        "cpu",
        "memory",
        "command",
        "reverse_proxy_image",
        "hosts",
        "service_type",
        "force_ssl",
        "health_check"
      )
    end
    exported
  end
end
