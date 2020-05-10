# frozen_string_literal: true

ENV["APP_ENV"] ||= ENV["RACK_ENV"] || "development"
environment(ENV["APP_ENV"])

if ENV["APP_ENV"] == "development" && !ENV["WEB_CONCURRENCY"]
  # better_errors and binding_of_caller works better with only the master process and one thread
  threads(1, 1)
else
  ENV["WEB_CONCURRENCY"] ||= "3"
  ENV["WEB_THREADS"] ||= "5"
  workers(ENV["WEB_CONCURRENCY"].to_i)
  thread_count = ENV["WEB_THREADS"].to_i
  threads(thread_count, thread_count)
end

preload_app!

app_path = File.expand_path("../..", __FILE__)
pidfile("#{app_path}/tmp/puma.pid")
bind("unix://#{app_path}/tmp/puma.sock")

if ENV["PORT"]
  port(ENV["PORT"])
end

if ENV["LOG_ENABLED"]
  stdout_redirect("#{app_path}/log/puma-stdout.log", "#{app_path}/log/puma-stderr.log", true)
end

if ENV["WEB_CONCURRENCY"]
  on_worker_shutdown do |index|
    # Delete stale metric files on worker shutdown
    Dir["#{app_path}/tmp/prometheus/*___#{Process.pid}.bin"].each do |file_path|
      File.unlink(file_path)
    end
  end
end
