source "https://rubygems.org"

ruby ">= 2.7.0"

gem "yajl-ruby", require: "yajl/json_gem"
gem "rake", require: false
gem "irb"
gem "rack"
gem "sinatra"
gem "puma", "~> 4.3"
gem "dotenv"
gem "redis"
gem "addressable"
gem "rack-ssl-enforcer"
gem "secure_headers"
# gem "clogger"
gem "heroku-env"
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
