# frozen_string_literal: true

ENV["APP_ENV"] ||= "development"

# Load secure_headers rake task
require "bundler/setup"
Bundler.require(:default, ENV["APP_ENV"])
load "tasks/tasks.rake"

if ENV["APP_ENV"] == "development"
  require "github-release-party/tasks/heroku"
end

Dir["lib/tasks/*.rake"].each { |f| load f }
