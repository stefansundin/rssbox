require "addressable/uri"

class HTTPResponse
  def initialize(response)
    @response = response
  end

  def raw
    @response
  end

  def body
    @response.body
  end

  def json
    @json ||= JSON.parse(@response.body)
  end

  def parsed_response
    json
  end

  def headers
    @response.header
  end

  def code
    @response.code.to_i
  end

  def success?
    @response.is_a?(Net::HTTPSuccess)
  end

  def redirect?
    @response.is_a?(Net::HTTPRedirection)
  end
end

class HTTP
  def self.get(url, options={headers: nil, query: nil})
    if defined?(self::BASE_URL)
      raise "url must start with /" if url[0] != "/"
      url = self::BASE_URL+url
    end

    if defined?(self::PARAMS)
      if url["?"]
        url += "&"+self::PARAMS
      else
        url += "?"+self::PARAMS
      end
    end

    if options[:query]
      params = options[:query].map { |k,v| "#{k}=#{v}" }.join("&")
      if url["?"]
        url += "&"+params
      else
        url += "?"+params
      end
    end

    uri = Addressable::URI.parse(url)
    opts = {
      use_ssl: uri.scheme == "https",
      open_timeout: 10,
      read_timeout: 10,
    }
    Net::HTTP.start(uri.host, uri.port, opts) do |http|
      headers = {}
      headers.merge!(self::HEADERS) if defined?(self::HEADERS)
      headers.merge!(opts[:headers]) if opts[:headers]
      endpoint = uri.path
      endpoint += "?"+uri.query if uri.query
      response = http.request_get(endpoint, headers)
      return HTTPResponse.new(response)
    end
  end
end
