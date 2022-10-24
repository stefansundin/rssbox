source "https://rubygems.org"

ruby ">= 2.7.0"

gem "rake", require: false
gem "irb", "=1.4.0" # https://github.com/ruby/irb/commit/99d3aa979dffece1fab06a7d5ebff4ae5da50aae
gem "rack"
gem "sinatra"
gem "puma"
gem "dotenv"
gem "redis"
gem "addressable"
gem "rack-ssl-enforcer"
gem "secure_headers"
gem "clogger"
gem "tzinfo"
gem "nokogiri"
gem "prometheus-client", require: "prometheus/middleware/exporter", git: "https://github.com/stefansundin/prometheus-client.git", branch: "master"

# dilbert feed
gem "feedjira"
gem "opengraph_parser"

gem "airbrake", require: false
gem "newrelic_rpm", require: false

group :development do
  gem "sinatra-contrib", require: "sinatra/reloader"
  gem "powder"
  # gem "binding_of_caller"
  # gem "better_errors"
  gem "pry-remote"
  gem "github-release-party"
end
