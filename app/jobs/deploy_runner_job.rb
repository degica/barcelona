class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  def perform(app, without_before_deploy:, description: "")
    app.events.create(level: :good, message: "Deploying to #{app.district.name} district: #{description}")
    before_deploy = app.before_deploy
    if before_deploy.present? && !without_before_deploy
      oneoff = app.oneoffs.create!(command: before_deploy)
      oneoff.run!(sync: true)
      if oneoff.exit_code != 0
        app.events.create(level: :error, message: "The command `#{before_deploy}` failed. Stopped deploying.")
        return
      else
        app.events.create(level: :good, message:  "before_deploy script `#{before_deploy}` successfully finished")
      end
    end

    app.services.each do |service|
      Rails.logger.info "Updating service #{service.service_name} ..."
      begin
        result = service.apply
        MonitorDeploymentJob.perform_later(service, deployment_id: result[:deployment_id])
      rescue => e
        Rails.logger.error "#{e.class}: #{e.message}"
        Rails.logger.error caller.join("\n")
        app.events.create(
          level: :error,
          message: "Deploy failed: Something went wrong with deploying #{service.name} service"
        )
      end
    end
  end
end
