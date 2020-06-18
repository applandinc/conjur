require 'appmap/middleware/remote_recording'

if %w[test development].member?(Rails.env)
  Rails.application.config.middleware.insert_after \
    Rails::Rack::Logger,
    AppMap::Middleware::RemoteRecording
end
