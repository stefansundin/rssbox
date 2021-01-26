# frozen_string_literal: true

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
  requests: prometheus.counter(:requests, labels: %i[service response_code], docstring: "Number of requests made to external services."),
  urls: prometheus.counter(:urls, docstring: "Number of URLs resolved."),

  # Cache:
  cache_keys: prometheus.counter(:cache_keys, labels: %i[prefix], docstring: "Number of keys in the cache."),
  cache_hits: prometheus.histogram(:cache_hits, labels: %i[prefix], buckets: Prometheus::Client::Histogram.exponential_buckets(start: 60, count: 10), docstring: "Cache hits, bucketed by cache age in seconds."),
  cache_hits_negative: prometheus.counter(:cache_hits_negative, labels: %i[prefix], docstring: "Number of negative cache hits."),
  cache_misses: prometheus.counter(:cache_misses, labels: %i[prefix], docstring: "Number of cache misses."),
  cache_errors: prometheus.counter(:cache_errors, labels: %i[prefix], docstring: "Number of cache content retrieval errors."),
  cache_updates_changed: prometheus.counter(:cache_updates_changed, labels: %i[prefix], docstring: "Number of cache updates where data changed."),
  cache_updates_unchanged: prometheus.counter(:cache_updates_unchanged, labels: %i[prefix], docstring: "Number of cache updates where data did not change."),
  cache_bytes: prometheus.gauge(:cache_bytes, store_settings: store_settings_sum, labels: %i[prefix], docstring: "Number of bytes of cached data."),
  cache_bytes_written: prometheus.counter(:cache_bytes_written, labels: %i[prefix], docstring: "Number of bytes of cache data written."),
  cache_bytes_read: prometheus.counter(:cache_bytes_read, labels: %i[prefix], docstring: "Number of bytes of cache data read."),
}
