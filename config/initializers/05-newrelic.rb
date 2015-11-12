if ENV["NEW_RELIC_LICENSE_KEY"] and ENV["NEW_RELIC_APP_NAME"]
  require "newrelic_rpm"
  NewRelic::Agent.after_fork(force_reconnect: true)
end
