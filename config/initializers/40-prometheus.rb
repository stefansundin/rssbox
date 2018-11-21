$prometheus = Prometheus::Client.registry

$metrics = {
  ratelimit: $prometheus.gauge(:ratelimit, "Remaining ratelimit for external services."),
  requests: $prometheus.counter(:requests, "Number of requests made to external services."),
  urls: $prometheus.counter(:urls, "Number of URLs resolved."),
}
