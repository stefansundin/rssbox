# frozen_string_literal: true

ENV["APP_ENV"] ||= ENV["RACK_ENV"] || "development"
ENV["APP_VERSION"] ||= ENV["HEROKU_RELEASE_VERSION"] || "unknown"

require "bundler/setup"
Bundler.require(:default, ENV["APP_ENV"])
Dotenv.overload

app_path = File.expand_path("..", __dir__)
Dir["#{app_path}/lib/**/*.rb"].sort.each { |f| require f }

# uncomment to get production error pages in development
# set :environment, :production

configure do
  # https://yhbt.net/clogger/
  # The default format below is similar to "Combined", but without $time_local and $http_user_agent (and using $ip instead of $remote_addr). Removing time and user-agent saves ~50% on log filesize.
  # The purpose of ~ is to allow for easier grepping with -E '^~' (i.e. filtering out exceptions and other crap)
  # Combined: $remote_addr - $remote_user [$time_local] $request" $status $response_length "$http_referer" "$http_user_agent"
  if ENV.has_key?("CLOGGER")
    disable :logging # Disable Sinatra's logger
    opts = {
      reentrant: true,
      format: ENV["CLOGGER_FORMAT"] || '~ $ip "$request" $status $response_length "$http_referer"',
    }
    if ENV.has_key?("CLOGGER_FILE")
      opts[:path] = ENV["CLOGGER_FILE"]
    else
      opts[:logger] = $stdout
    end
    use Clogger, opts
  end

  use Rack::Deflater, sync: false
  use Rack::SslEnforcer, only_hosts: (ENV["SSL_ENFORCER_HOST"] || /\.herokuapp\.com$/)
  use SecureHeaders::Middleware
  use XRobotsTag
  use Prometheus::Middleware::Exporter

  set :protection, :except => [:frame_options] # Disable things that secure_headers handles
  set :erb, trim: "-"
  disable :absolute_redirects
  # Look up Rack::Mime::MIME_TYPES to see rack defaults
  mime_type :opensearch, "application/opensearchdescription+xml"
  settings.add_charset << "application/atom+xml"
end

configure :production do
  set :static_cache_control, [:public, :max_age => 86400]
end

configure :development do
  if defined?(BetterErrors)
    use BetterErrors::Middleware
    BetterErrors.application_root = File.expand_path("..", __dir__)
  end
end

Dir["#{app_path}/config/initializers/*.rb"].sort.each { |f| require f }
Dir["#{app_path}/app/**/*.rb"].sort_fs.each { |f| require f }
