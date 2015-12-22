if ENV["AIRBRAKE_API_KEY"]
  Airbrake.configure do |config|
    config.host = ENV["AIRBRAKE_HOST"]
    config.project_id = ENV["AIRBRAKE_PROJECT_ID"]
    config.project_key = ENV["AIRBRAKE_API_KEY"]
  end

  use Airbrake::Rack::Middleware
  enable :raise_errors
end
