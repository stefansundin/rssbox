# Modified version of https://github.com/rack/rack/blob/7b273ad9fc4ced15dcc28dafba51173adef5b180/lib/rack/common_logger.rb

class BetterLogger
  FORMAT = %{~ %s - %s [%s] "%s %s%s%s %s" %d %s %0.4f "%s" "%s"\n}

  def initialize(app, logger = nil)
    @app = app
    @logger = logger
  end

  def call(env)
    began_at = Rack::Utils.clock_time
    status, headers, body = response = @app.call(env)

    response[2] = Rack::BodyProxy.new(body) { log(env, status, headers, began_at) }
    response
  end

  private

  def log(env, status, response_headers, began_at)
    request = Rack::Request.new(env)
    length = extract_content_length(response_headers)
    msg = sprintf(FORMAT,
      request.get_header("HTTP_X_FORWARDED_FOR") || request.ip || "-",
      request.get_header("REMOTE_USER") || "-",
      Time.now.strftime("%d/%b/%Y:%H:%M:%S %z"),
      request.request_method,
      request.script_name,
      request.path_info,
      request.query_string.empty? ? "" : "?#{request.query_string}",
      request.get_header(Rack::SERVER_PROTOCOL),
      status.to_s[0..3],
      length,
      Rack::Utils.clock_time - began_at,
      request.get_header("HTTP_REFERER") || "-",
      request.get_header("HTTP_USER_AGENT") || "-",
    )

    msg.gsub!(/[^[:print:]\n]/) { |c| sprintf("\\x%x", c.ord) }

    logger = @logger || request.get_header(Rack::RACK_ERRORS)
    if logger.respond_to?(:write)
      logger.write(msg)
    else
      logger << msg
    end
  end

  def extract_content_length(headers)
    value = headers[Rack::CONTENT_LENGTH]
    !value || value.to_s == '0' ? '-' : value
  end
end
