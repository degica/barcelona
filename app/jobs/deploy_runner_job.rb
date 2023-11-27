class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  retry_on(StandardError, attempts: 1) do |job, e|
    job.notify(level: :error, message: "Deploy failed. Check logs to see what happened.")
  end

  def perform(heritage, without_before_deploy:, description: "")
    @heritage = heritage
    heritage.with_lock do
      if other_deploy_in_progress?(heritage)
        notify(level: :error, message: "The other deployment is in progress. Stopped deploying.")
        return
      end

      loop do
        break unless heritage.cf_executor.in_progress?
        puts "Waiting for heritage stack to be complete"
        sleep 5
      end

      notify(message: "Deploying to #{heritage.district.name} district: #{description}")
      before_deploy = heritage.before_deploy
      if before_deploy.present? && !without_before_deploy
        oneoff = heritage.oneoffs.create!(command: before_deploy)
        oneoff.run!(sync: true)
        if oneoff.exit_code != 0
          notify(level: :error, message: "The command `#{before_deploy}` failed. Stopped deploying.")
          return
        else
          notify(message: "before_deploy script `#{before_deploy}` successfully finished")
        end
      end

      heritage.services.each do |service|
        result = service.apply
        MonitorDeploymentJob.perform_later(service, deployment_id: result[:deployment_id])
      end
    end
  end

  def other_deploy_in_progress?(heritage)
    return false if heritage.version == 1
    heritage.services.map { |s| !s.deployment_finished?(nil) }.any?
  end

  def notify(level: :good, message:)
    Event.new(@heritage.district).notify(level: level, message: "[#{@heritage.name}] #{message}")
  end
end
