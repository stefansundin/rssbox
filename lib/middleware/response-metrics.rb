class ResponseMetrics
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if status != 404
      labels = {
        method: env["REQUEST_METHOD"],
        status: status,
        path_prefix: self.class.get_first_path_segment(env["PATH_INFO"]),
      }
      body_size = 0
      body.each { |b| body_size += b.bytesize }
      $metrics[:responses_total].increment(labels: labels)
      if body_size > 0
        $metrics[:response_size_bytes].increment(by: body_size, labels: labels)
      end
    end

    return [status, headers, body]
  end

  private

  def self.get_first_path_segment(path_string)
    parts = path_string.split('/')
    if parts.empty? || parts.length <= 1
      return path_string
    else
      return "/" + parts[1]
    end
  end
end
