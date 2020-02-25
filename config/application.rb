# frozen_string_literal: true

ENV["APP_ENV"] ||= ENV["RACK_ENV"] || "development"

require "bundler/setup"
Bundler.require(:default, ENV["APP_ENV"])

app_path = File.expand_path("../..", __FILE__)
Dir["#{app_path}/lib/**/*.rb"].sort.each { |f| require f }

# Expose the request path in the exception message for Sinatra::NotFound
# This makes it easier to scan the list of errors in Airbrake to see what paths causes 404 errors
# https://github.com/sinatra/sinatra/pull/1566
module Sinatra
  class Base
    def route_missing
      if @app
        forward
      else
        raise NotFound, "#{request.request_method} #{request.path_info}"
      end
    end
  end
end

# uncomment to get production error pages in development
# set :environment, :production

configure do
  use Rack::Deflater
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
    BetterErrors.application_root = File.expand_path("..")
  end
end

Dir["#{app_path}/config/initializers/*.rb"].sort.each { |f| require f }
Dir["#{app_path}/app/**/*.rb"].sort.each { |f| require f }
