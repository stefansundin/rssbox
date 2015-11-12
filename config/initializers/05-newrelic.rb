if ENV["NEW_RELIC_LICENSE_KEY"]
  NewRelic::Agent.after_fork(force_reconnect: true)
end
