# only allow search engine indexing of the main page

module App
  class XRobotsTag
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      if env["PATH_INFO"] != "/"
        headers["X-Robots-Tag"] = "noindex"
      end
      return [status, headers, body]
    end
  end
end
