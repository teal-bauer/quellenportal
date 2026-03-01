Rails.application.configure do
  config.solid_queue.shutdown_timeout = 30
  config.solid_queue.connects_to = { database: { writing: :queue } }
end
