# frozen_string_literal: true
# https://prometheus.io/docs/practices/naming/

# Use DirectFileStore if we run multiple processes
store_settings_most_recent = {}
store_settings_sum = {}
if ENV["WEB_CONCURRENCY"]
  require "prometheus/client/data_stores/direct_file_store"
  app_path = File.expand_path("../..", __dir__)
  Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: "#{app_path}/tmp/prometheus/")
  store_settings_most_recent[:aggregation] = Prometheus::Client::DataStores::DirectFileStore::MOST_RECENT
  store_settings_sum[:aggregation] = Prometheus::Client::DataStores::DirectFileStore::SUM

  # Clean up old metric files
  Dir["#{app_path}/tmp/prometheus/*.bin"].each do |file_path|
    File.unlink(file_path)
  end
end

prometheus = Prometheus::Client.registry

$metrics = {
  ratelimit: prometheus.gauge(:ratelimit, store_settings: store_settings_most_recent, labels: %i[service endpoint], docstring: "Remaining ratelimit for external services."),
  requests_total: prometheus.counter(:requests_total, labels: %i[service response_code], docstring: "Number of requests made to external services."),
  urls_resolved_total: prometheus.counter(:urls_resolved_total, docstring: "Number of URLs resolved."),

  # Response metrics:
  responses_total: prometheus.counter(:responses_total, labels: %i[method status path_prefix], docstring: "Number of responses made."),
  response_size_bytes: prometheus.counter(:response_size_bytes, labels: %i[method status path_prefix], docstring: "Number of bytes in response bodies."),

  # Cache:
  cache_keys_total: prometheus.counter(:cache_keys_total, labels: %i[prefix], docstring: "Number of keys in the cache."),
  cache_hits_duration_seconds: prometheus.histogram(:cache_hits_duration_seconds, labels: %i[prefix], buckets: Prometheus::Client::Histogram.exponential_buckets(start: 60, count: 10), docstring: "Cache hits, bucketed by cache age in seconds."),
  cache_hits_negative_total: prometheus.counter(:cache_hits_negative_total, labels: %i[prefix], docstring: "Number of negative cache hits."),
  cache_misses_total: prometheus.counter(:cache_misses_total, labels: %i[prefix], docstring: "Number of cache misses."),
  cache_errors_total: prometheus.counter(:cache_errors_total, labels: %i[prefix], docstring: "Number of cache content retrieval errors."),
  cache_updates_changed_total: prometheus.counter(:cache_updates_changed_total, labels: %i[prefix], docstring: "Number of cache updates where data changed."),
  cache_updates_unchanged_total: prometheus.counter(:cache_updates_unchanged_total, labels: %i[prefix], docstring: "Number of cache updates where data did not change."),
  cache_size_bytes: prometheus.gauge(:cache_size_bytes, store_settings: store_settings_sum, labels: %i[prefix], docstring: "Number of bytes of cached data."),
  cache_written_bytes: prometheus.counter(:cache_written_bytes, labels: %i[prefix], docstring: "Number of bytes of cache data written."),
  cache_read_bytes: prometheus.counter(:cache_read_bytes, labels: %i[prefix], docstring: "Number of bytes of cache data read."),
}
