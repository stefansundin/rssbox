$prometheus = Prometheus::Client.registry

$metrics = {
  ratelimit: $prometheus.gauge(:ratelimit, labels: %i[service], docstring: "Remaining ratelimit for external services."),
  requests: $prometheus.counter(:requests, labels: %i[service response_code], docstring: "Number of requests made to external services."),
  urls: $prometheus.counter(:urls, docstring: "Number of URLs resolved."),
}
