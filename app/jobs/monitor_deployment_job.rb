class MonitorDeploymentJob < ActiveJob::Base
  queue_as :default

  def perform(service, count: 0, deployment_id: nil)
    if service.deployment_finished?(deployment_id)
      service.app.events.create!(level: :good, message: "#{service.name} service deployed")
    elsif count > 200
      # deploys not finished after 1000 seconds are marked as timeout
      service.app.events.create!(level: :error, message: "Deploying #{service.name} service has not finished for a while.")
    else
      MonitorDeploymentJob.set(wait: 5.seconds).perform_later(service,
                                                              count: count + 1,
                                                              deployment_id: deployment_id)
    end
  end
end
