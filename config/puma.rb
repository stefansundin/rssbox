# frozen_string_literal: true

ENV["APP_ENV"] ||= "development"
environment(ENV["APP_ENV"])

if ENV["APP_ENV"] == "development"
  # better_errors and binding_of_caller works better with only one process and thread
  workers(1)
  threads(1, 1)
else
  workers(ENV["WEB_CONCURRENCY"] || 3)
  thread_count = ENV["WEB_THREADS"] || 5
  threads(thread_count, thread_count)
end

preload_app!

app_path = File.expand_path("../..", __FILE__)
pidfile("#{app_path}/tmp/puma.pid")
bind("unix://#{app_path}/tmp/puma.sock")

if ENV["LOG_ENABLED"]
  stdout_redirect("#{app_path}/log/puma-stdout.log", "#{app_path}/log/puma-stderr.log", true)
end
