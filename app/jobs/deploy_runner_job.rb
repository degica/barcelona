class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  def perform(heritage)
    heritage.services.each do |service|
      Rails.logger.info "Updating service #{service.service_name} ..."
      service.apply_to_ecs(heritage.image_path)
    end
  end
end
