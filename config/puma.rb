# frozen_string_literal: true

ENV["APP_ENV"] ||= ENV["RACK_ENV"] || "development"
environment(ENV["APP_ENV"])

if ENV["APP_ENV"] == "development"
  # better_errors and binding_of_caller works better with only the master process and one thread
  threads(1, 1)
else
  if ENV["WEB_CONCURRENCY"]
    workers(ENV["WEB_CONCURRENCY"].to_i)
  end
  # The number of threads to run per worker. Note that this also sets the minimum number of threads to the same value, which is a recommended approach, especially in a single-app environment such as Heroku. See https://github.com/puma/puma-heroku
  threads_count = Integer(ENV["MAX_THREADS"] || 5)
  threads(threads_count, threads_count)
end

preload_app!

app_path = File.expand_path("../..", __FILE__)
pidfile("#{app_path}/tmp/puma.pid")
bind("unix://#{app_path}/tmp/puma.sock")

if ENV["LOG_ENABLED"]
  stdout_redirect("#{app_path}/log/puma-stdout.log", "#{app_path}/log/puma-stderr.log", true)
end
