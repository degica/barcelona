class MonitorDeploymentJob < ActiveJob::Base
  queue_as :default

  def perform(service)
    @service = service
    Rails.logger.info "Monitoring deployment of #{service.service_name}"

    if wait_active
      service.heritage.events.create!(level: :good, message: "#{service.service_name} deployed")
    else
      service.heritage.events.create!(level: :error, message: "Deploying #{service.service_name} timed out")
    end
  end

  def wait_active
    1000.times do
      @service.fetch_ecs_service
      return true if @service.status == :active
      sleep 3
    end

    false
  end
end
