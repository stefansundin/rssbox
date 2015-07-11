environment = ENV["RACK_ENV"] || "development"

if environment == "development"
  require "github-release-party/tasks/heroku"
end

Dir["lib/tasks/*.rake"].each { |f| load f }

# activerecord
require "sinatra/activerecord/rake"
namespace :db do
  task :load_config do
    require "./app"
  end
end
