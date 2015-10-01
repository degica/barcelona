class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  def perform(heritage)
    before_deploy = heritage.before_deploy
    if before_deploy.present?
      oneoff = heritage.oneoffs.create!(command: before_deploy)
      oneoff.run!(sync: true)
      if oneoff.exit_code != 0
        Rails.logger.error "The command `#{before_deploy.join(" ")}` failed. Stopped deploying."
        return
      else
        Rails.logger.info "The command `#{before_deploy.join(" ")}` successfuly finished"
      end
    end

    heritage.services.each do |service|
      Rails.logger.info "Updating service #{service.service_name} ..."
      service.apply_to_ecs(heritage.image_path)
    end
  end
end
