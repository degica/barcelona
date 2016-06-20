class Release < ActiveRecord::Base
  belongs_to :app, required: true, inverse_of: :releases

  serialize :app_params, JSON

  before_create do |release|
    release.app_params = export_app
    release.version = app.releases.count + 1
  end

  def rollback
    app.attributes = app_params
    app.save_and_deploy!(
      without_before_deploy: true,
      description: "Rolled back to version #{version}"
    )
  end

  def export_app
    exported = app.attributes.slice("image_name", "image_tag")
    exported["services_attributes"] = app.services.map do |service|
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
