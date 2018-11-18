$prometheus = Prometheus::Client.registry

$metrics = {
  ratelimit: $prometheus.gauge(:ratelimit, docstring: "Remaining ratelimit for external services.", labels: [:service]),
  requests: $prometheus.counter(:requests, docstring: "Number of requests made to external services.", labels: [:service, :response_code]),
  urls: $prometheus.counter(:urls, docstring: "Number of URLs resolved."),
}
