class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  def perform(heritage, without_before_deploy:, description: "")
    heritage.with_lock do
      if other_deploy_in_progress?(heritage)
        notify(heritage, level: :error, message: "The other deployment is in progress. Stopped deploying.")
        return
      end

      loop do
        break unless heritage.cf_executor.in_progress?
        puts "Waiting for heritage stack to be complete"
        sleep 5
      end

      notify(heritage, message: "Deploying to #{heritage.district.name} district: #{description}")
      before_deploy = heritage.before_deploy
      if before_deploy.present? && !without_before_deploy
        oneoff = heritage.oneoffs.create!(command: before_deploy)
        oneoff.run!(sync: true)
        if oneoff.exit_code != 0
          notify(heritage, level: :error, message: "The command `#{before_deploy}` failed. Stopped deploying.")
          return
        else
          notify(heritage, message: "before_deploy script `#{before_deploy}` successfully finished")
        end
      end

      heritage.services.each do |service|
        begin
          result = service.apply
          MonitorDeploymentJob.perform_later(service, deployment_id: result[:deployment_id])
        rescue => e
          Rails.logger.error "#{e.class}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          notify(
            heritage,
            level: :error,
            message: "Deploy failed: Something went wrong with deploying #{service.name} service"
          )
        end
      end
    end
  rescue => e
    # Retrying failing deployment doesn't make any sense.
    # Just stop the deployment and let users know it thorough notification
    notify(heritage, level: :error, message: "Error occurred: #{e.message}")
  end

  def other_deploy_in_progress?(heritage)
    return false if heritage.version == 1
    heritage.services.map { |s| !s.deployment_finished?(nil) }.any?
  end

  def notify(heritage, level: :good, message:)
    Event.new(heritage.district).notify(level: level, message: "[#{heritage.name}] #{message}")
  end
end
