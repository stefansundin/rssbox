# frozen_string_literal: true

ENV["RACK_ENV"] ||= "development"

# Load secure_headers rake task
require "bundler/setup"
Bundler.require(:default, ENV["RACK_ENV"])
load "tasks/tasks.rake"

if ENV["RACK_ENV"] == "development"
  require "github-release-party/tasks/heroku"
end

Dir["lib/tasks/*.rake"].each { |f| load f }
