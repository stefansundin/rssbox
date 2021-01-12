# frozen_string_literal: true

# Use DirectFileStore if we run multiple processes
store_settings = {}
if ENV["WEB_CONCURRENCY"]
  require "prometheus/client/data_stores/direct_file_store"
  app_path = File.expand_path("../..", __dir__)
  Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: "#{app_path}/tmp/prometheus/")
  store_settings[:aggregation] = :most_recent

  # Clean up old metric files
  Dir["#{app_path}/tmp/prometheus/*.bin"].each do |file_path|
    File.unlink(file_path)
  end
end

prometheus = Prometheus::Client.registry

$metrics = {
  ratelimit: prometheus.gauge(:ratelimit, store_settings: store_settings, labels: %i[service endpoint], docstring: "Remaining ratelimit for external services."),
  requests: prometheus.counter(:requests, labels: %i[service response_code], docstring: "Number of requests made to external services."),
  urls: prometheus.counter(:urls, docstring: "Number of URLs resolved."),
}
