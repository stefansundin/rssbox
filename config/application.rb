ENV["RACK_ENV"] ||= "development"

require "bundler/setup"
Bundler.require(:default, ENV["RACK_ENV"])

app_path = File.expand_path("../..", __FILE__)
Dir["#{app_path}/config/initializers/*.rb"].each { |f| require f }

set :erb, trim: "-"

# development specific
configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path(".")
end
