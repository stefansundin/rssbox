source "https://rubygems.org"

ruby ">= 3.2.0"

gem "rake", require: false
gem "irb"
gem "rack"
gem "sinatra"
gem "puma"
gem "dotenv"
gem "redis"
gem "addressable"
gem "rack-ssl-enforcer"
gem "secure_headers"
gem "tzinfo"
gem "nokogiri"
gem "prometheus-client", require: "prometheus/middleware/exporter"
gem "opengraph_parser"

# https://github.com/tmm1/rbtrace/issues/73
install_if -> { RUBY_PLATFORM.start_with?("arm", "aarch", "x86") } do
  gem "rbtrace"
end

gem "airbrake", require: false
gem "newrelic_rpm", require: false

# openssl 3.6.0 is causing issues in the version of the openssl gem that ships with Ruby. https://github.com/ruby/openssl/issues/949
gem "openssl", require: false

group :development do
  gem "sinatra-contrib", require: "sinatra/reloader"
  gem "pry"
  gem "binding_of_caller"
  gem "better_errors"
  gem "github-release-party"
end
