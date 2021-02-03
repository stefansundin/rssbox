# frozen_string_literal: true

ENV["APP_ENV"] ||= ENV["RACK_ENV"] || "development"
environment(ENV["APP_ENV"])

if ENV["APP_ENV"] == "development" && !ENV["WEB_CONCURRENCY"]
  # better_errors and binding_of_caller works better in single mode with only one thread
  threads(1, 1)
end

preload_app!

app_path = File.expand_path("..", __dir__)
pidfile("#{app_path}/tmp/puma.pid")
bind("unix://#{app_path}/tmp/puma.sock")

if ENV["PORT"]
  port(ENV["PORT"])
end

if ENV.has_key?("LOGFILE")
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
