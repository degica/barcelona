class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  def perform(heritage, without_before_deploy:, description: "")
    heritage.with_lock do
      if other_deploy_in_progress?(heritage)
        heritage.events.create(level: :error, message: "The other deployment is in progress. Stopped deploying.")
        return
      end

      heritage.events.create(level: :good, message: "Deploying to #{heritage.district.name} district: #{description}")
      before_deploy = heritage.before_deploy
      if before_deploy.present? && !without_before_deploy
        oneoff = heritage.oneoffs.create!(command: before_deploy)
        oneoff.run!(sync: true)
        if oneoff.exit_code != 0
          heritage.events.create(level: :error, message: "The command `#{before_deploy}` failed. Stopped deploying.")
          return
        else
          heritage.events.create(level: :good, message:  "before_deploy script `#{before_deploy}` successfully finished")
        end
      end

      heritage.services.each do |service|
        Rails.logger.info "Updating service #{service.service_name} ..."
        begin
          result = service.apply
          MonitorDeploymentJob.perform_later(service, deployment_id: result[:deployment_id])
        rescue => e
          Rails.logger.error "#{e.class}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          heritage.events.create(
            level: :error,
            message: "Deploy failed: Something went wrong with deploying #{service.name} service"
          )
        end
      end
    end
  rescue => e
    # Retrying failing deployment doesn't make any sense.
    # Just stop the deployment and let users know it thorough notification
    heritage.events.create(level: :error, message: "Error occurred: #{e.message}")
  end

  def other_deploy_in_progress?(heritage)
    return false if heritage.version == 1
    heritage.services.map { |s| !s.deployment_finished?(nil) }.any?
  end
end
