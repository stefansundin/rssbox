# frozen_string_literal: true

ENV["RACK_ENV"] ||= "development"

require "bundler/setup"
Bundler.require(:default, ENV["RACK_ENV"])

# uncomment to get production error pages in development
# set :environment, :production

configure do
  use Rack::SslEnforcer, only_hosts: /\.herokuapp\.com$/
  use SecureHeaders::Middleware
  set :erb, trim: "-"
  # Look up Rack::Mime::MIME_TYPES to see rack defaults
  mime_type :opensearch, "application/opensearchdescription+xml"
  settings.add_charset << "application/atom+xml"
end

configure :production do
  set :static_cache_control, [:public, :max_age => 86400]
end

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path(".")

  # puma autoload warnings
  require "tilt/erubis"
end

# require things
app_path = File.expand_path("../..", __FILE__)
Dir["#{app_path}/config/initializers/*.rb"].each { |f| require f }
Dir["#{app_path}/app/**/*.rb"].each { |f| require f }
