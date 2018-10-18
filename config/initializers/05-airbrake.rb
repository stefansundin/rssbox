# frozen_string_literal: true

if ENV["AIRBRAKE_API_KEY"]
  require "airbrake"
  Airbrake.configure do |config|
    config.host = ENV["AIRBRAKE_HOST"] if ENV["AIRBRAKE_HOST"]
    config.project_id = ENV["AIRBRAKE_PROJECT_ID"]
    config.project_key = ENV["AIRBRAKE_API_KEY"]
  end

  use Airbrake::Rack::Middleware
  enable :raise_errors

  Airbrake.add_filter do |notice|
    # Bots gonna bot
    notice.ignore! if notice[:errors].any? { |e| e[:type] == "Sinatra::NotFound" } && (/\/wp-(?:admin|includes|content|login)/ =~ notice[:context][:url] || /\/facebook\/\d+\/?$/ =~ notice[:context][:url])

    # Throttle errors from external services. My free plan runs out of quota a lot, often because of Instagram issues.
    # The first error is reported, but a redis key is set that prevents further errors from the same service to be reported, until the key has expired.
    # The value in the redis key counts the number of throttled errors, although that information is not persisted anywhere.
    notice[:errors].each do |e|
      if Object.const_get(e[:type]) <= HTTPError
        throttle_key = "airbrake_throttle:#{e[:type]}"
        if $redis.exists(throttle_key)
          notice.ignore!
          $redis.incr(throttle_key)
          puts "Throttling reporting #{e[:type]} to Airbrake. Throttle counter: #{$redis.get(throttle_key)}."
        else
          $redis.setex(throttle_key, ENV["AIRBRAKE_THROTTLE_DURATION"] || 3600, 0)
        end
      end
    end
  end
end
