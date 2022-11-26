# frozen_string_literal: true

ENV["APP_ENV"] ||= ENV["RACK_ENV"] || "development"

# Load secure_headers rake task
require "bundler/setup"
Bundler.require(:default, ENV["APP_ENV"])
load "tasks/tasks.rake"

if ENV["APP_ENV"] == "development"
  require "github-release-party/tasks/fly"
end

Dir["lib/tasks/*.rake"].sort.each { |f| load f }
