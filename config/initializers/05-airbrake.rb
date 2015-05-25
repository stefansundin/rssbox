if ENV["AIRBRAKE_KEY"]
  Airbrake.configure do |config|
    config.host = ENV["AIRBRAKE_HOST"]
    config.api_key = ENV["AIRBRAKE_KEY"]
    config.secure = true

    # Uncomment this to get errors in development environment:
    config.development_environments = []
  end

  use Airbrake::Sinatra
  enable :raise_errors
end
