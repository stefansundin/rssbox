if ENV["NEW_RELIC_LICENSE_KEY"]
  require "newrelic_rpm"
  NewRelic::Agent.after_fork(force_reconnect: true)
  GC::Profiler.enable
end
