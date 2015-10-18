class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  def perform(heritage)
    heritage.events.create(level: :good, message: "Deploying...")
    before_deploy = heritage.before_deploy
    if before_deploy.present?
      oneoff = heritage.oneoffs.create!(command: before_deploy)
      oneoff.run!(sync: true)
      if oneoff.exit_code != 0
        heritage.events.create(level: :error, message: "The command `#{before_deploy}` failed. Stopped deploying.")
        return
      else
        heritage.events.create(level: :good, message:  "`#{before_deploy}` successfuly finished")
      end
    end

    heritage.services.each do |service|
      Rails.logger.info "Updating service #{service.service_name} ..."
      service.apply
    end

    heritage.services.each do |service|
      MonitorDeploymentJob.perform_later(service)
    end
  end
end
