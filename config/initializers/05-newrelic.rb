if ENV["NEW_RELIC_LICENSE_KEY"] and ENV["NEW_RELIC_APP_NAME"]
  NewRelic::Agent.after_fork(force_reconnect: true)
end
