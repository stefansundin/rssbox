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

# ENV["HOST"] = "[::]" # Use this to bind to IPv6
ENV["HOST"] ||= "0.0.0.0"

if ENV["PORT"]
  port(ENV["PORT"], ENV["HOST"])
end

keyfile = Dir.glob("#{app_path}/config/certs/*.key")[0]
if keyfile
  certfile = keyfile[..-4] + "crt"
  ssl_bind(ENV["HOST"], ENV["PORT_TLS"] || "9292", {
    cert: certfile,
    key: keyfile,
  })
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
