require File.expand_path('../boot', __FILE__)

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../app/middlewares/exception_handler"

module Barcelona
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

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
