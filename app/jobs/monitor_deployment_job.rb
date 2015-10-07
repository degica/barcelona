class MonitorDeploymentJob < ActiveJob::Base
  queue_as :default

  def perform(service, count: 0)
    service.fetch_ecs_service
    if service.status == :active
      service.heritage.events.create!(level: :good, message: "#{service.service_name} deployed")
    elsif count > 200
      # deploys not finished after 1000 seconds are marked as timeout
      service.heritage.events.create!(level: :error, message: "Deploying #{service.service_name} timed out")
    else
      MonitorDeploymentJob.set(wait: 5.seconds).perform_later(service, count + 1)
    end
  end
end
