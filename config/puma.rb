threads 2, 16
workers 2
preload_app!
port ENV['PORT']

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end
