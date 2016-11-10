require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../app/middlewares/exception_handler"

module Barcelona
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.middleware.insert_after ActionDispatch::DebugExceptions, ExceptionHandler

    config.active_job.queue_adapter = :delayed_job
    config.eager_load_paths += [
      "#{Rails.root}/lib"
    ]

    ### Log configurations

    config.filter_parameters += [:token, :aws_secret_access_key, :env_vars, :public_key, :roles]

    config.lograge.enabled = true
    config.lograge.custom_options = -> event do
      params = event.payload[:params].except('controller', 'action')
      {
        user: event.payload[:user],
        params: params
      }.compact
    end
  end
end
