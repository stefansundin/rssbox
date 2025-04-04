# frozen_string_literal: true

ENV["APP_ENV"] ||= ENV["RACK_ENV"] || "development"
ENV["APP_VERSION"] ||= ENV["HEROKU_RELEASE_VERSION"] || File.mtime(__FILE__).iso8601

require "bundler/setup"
Bundler.require(:default, ENV["APP_ENV"])
Dotenv.overload

app_path = File.expand_path("..", __dir__)
Dir["#{app_path}/lib/**/*.rb"].sort.each { |f| require f }

# uncomment to get production error pages in development
# set :environment, :production

configure do
  # Use a custom logger
  disable :logging
  use BetterLogger

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
  set :static_cache_control, [:public, :no_cache]
end

configure :development do
  if defined?(BetterErrors)
    use BetterErrors::Middleware
    BetterErrors.application_root = File.expand_path("..", __dir__)
  end
end

Dir["#{app_path}/config/initializers/*.rb"].sort.each { |f| require f }
Dir["#{app_path}/app/**/*.rb"].sort_fs.each { |f| require f }
