# Enable error reporting with Honeybadger if API key is present
if ENV['HONEYBADGER_API_KEY']
  require 'honeybadger'

  Honeybadger.configure do |config|
    config.api_key = ENV['HONEYBADGER_API_KEY']
  end
end
