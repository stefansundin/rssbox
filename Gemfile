source "https://rubygems.org"

ruby ">= 2.5.0"

gem "yajl-ruby", require: "yajl/json_gem"
gem "rake", require: false
gem "rack"
gem "sinatra"
gem "puma"
gem "dotenv"
gem "redis"
gem "redis-namespace"
gem "addressable"
gem "rack-ssl-enforcer"
gem "secure_headers"
# gem "clogger"
gem "heroku-env"
gem "activesupport"
gem "nokogiri"
gem "prometheus-client", require: "prometheus/middleware/exporter"

# dilbert feed
gem "feedjira"
gem "opengraph_parser"

group :production do
  gem "airbrake", require: false
  gem "newrelic_rpm", require: false
end

group :development do
  gem "sinatra-contrib", require: "sinatra/reloader"
  gem "powder"
  # gem "binding_of_caller"
  # gem "better_errors"
  gem "pry-remote"
  gem "github-release-party"
end
