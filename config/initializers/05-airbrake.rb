# frozen_string_literal: true

if ENV["AIRBRAKE_API_KEY"]
  require "airbrake"

  Airbrake.configure do |config|
    config.host = ENV["AIRBRAKE_HOST"] if ENV["AIRBRAKE_HOST"]
    config.project_id = ENV["AIRBRAKE_PROJECT_ID"]
    config.project_key = ENV["AIRBRAKE_API_KEY"]
    config.environment = ENV["AIRBRAKE_ENVIRONMENT"] if ENV["AIRBRAKE_ENVIRONMENT"]
  end

  use Airbrake::Rack::Middleware
  enable :raise_errors

  airbrake_throttle = {}

  Airbrake.add_filter do |notice|
    # Bots gonna bot
    if notice[:errors].any? { |e| e[:type] == "Sinatra::NotFound" }
      if notice[:context][:httpMethod] == "OPTIONS" || !ENV.has_key?("AIRBRAKE_REPORT_404")
        notice.ignore!
        next
      elsif ENV["AIRBRAKE_REPORT_404"] == "true"
        next
      end

      # Set the variable to a regexp to ignore certain spammy paths
      re = Regexp.new(ENV["AIRBRAKE_REPORT_404"], Regexp::IGNORECASE)
      if re =~ notice[:context][:url]
        notice.ignore!
        next
      end
    end

    # Ignore SIGTERM which is sent on deploy and restart
    if notice[:errors].any? { |e| e[:type] == "SignalException" && e[:message] == "SIGTERM" }
      notice.ignore!
      next
    end

    # Throttle errors from external services. My free plan runs out of quota a lot, often because of Instagram issues.
    # The first error is reported, but a redis key is set that prevents further errors from the same service to be reported, until the key has expired.
    # The value in the redis key counts the number of throttled errors, although that information is not persisted anywhere.
    notice[:errors].each do |e|
      if Object.const_get(e[:type]) <= App::HTTPError
        throttle_key = e[:type].to_s
        if airbrake_throttle[throttle_key] && Time.now.to_i < airbrake_throttle[throttle_key] + 3600
          notice.ignore!
          puts "Throttling reporting #{e[:type]} to Airbrake."
        else
          airbrake_throttle[throttle_key] = Time.now.to_i
        end
      end
    end
  end
end
