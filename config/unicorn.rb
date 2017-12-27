# frozen_string_literal: true

ENV["RACK_ENV"] ||= "development"
if ENV["RACK_ENV"] == "development"
  # better_errors and binding_of_caller works better with only one process
  worker_processes 1
else
  worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)
end

timeout 60
preload_app true

app_path = File.expand_path("../..", __FILE__)
working_directory app_path
pid "#{app_path}/tmp/unicorn.pid"
listen "#{app_path}/tmp/unicorn.sock"

if ENV["LOG_ENABLED"]
  stdout_path "#{app_path}/log/unicorn-stdout.log"
  stderr_path "#{app_path}/log/unicorn-stderr.log"
end


# reload environment variables on restart (used by init.d script in Vagrantfile)
before_exec do |server|
  if ENV["ENV_SCRIPT"]
    File.readlines(ENV["ENV_SCRIPT"]).each do |line|
      next unless line =~ /^export /
      k, v = line.strip.sub(/^export /, "").split("=", 2)
      next if k == "PATH" # Don't update PATH
      v = v[1..-2] if (v[0] == '"' and v[-1] == '"') or (v[0] == "'" and v[-1] == "'")
      if v == ""
        $stderr.puts "Unsetting ENV[#{k}]"
        ENV.delete k
      elsif ENV[k] != v
        $stderr.puts "Updating ENV[#{k}] to #{v} (old value: #{ENV[k]})"
        ENV[k] = v
      end
    end
  end
end

before_fork do |server, worker|
  Signal.trap "TERM" do
    puts "Unicorn master intercepting TERM and sending myself QUIT instead"
    Process.kill "QUIT", Process.pid
  end
end

after_fork do |server, worker|
  Signal.trap "TERM" do
    puts "Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT"
  end
end
