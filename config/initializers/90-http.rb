# frozen_string_literal: true

class HTTP
  def self.get(url, options={headers: nil, query: nil})
    relative_url = (url[0] == "/")

    if defined?(self::BASE_URL) and relative_url
      url = self::BASE_URL+url
    end

    if defined?(self::PARAMS) and relative_url
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

    uri = Addressable::URI.parse(url).normalize
    opts = {
      use_ssl: uri.scheme == "https",
      open_timeout: 10,
      read_timeout: 10,
    }
    Net::HTTP.start(uri.host, uri.port, opts) do |http|
      headers = {}
      headers.merge!(self::HEADERS) if defined?(self::HEADERS) and relative_url
      headers.merge!(options[:headers]) if options[:headers]
      response = http.request_get(uri.request_uri, headers)
      return HTTPResponse.new(response, uri.to_s)
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError, EOFError
    self::ERROR_CLASS ||= HTTPError
    raise(self::ERROR_CLASS, $!)
  end
end

class HTTPResponse
  def initialize(response, url)
    @response = response
    @url = url
  end

  def raw
    @response
  end

  def url
    @url
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

  def redirect_url
    raise("not a redirect") if !redirect?
    url = @response.header["location"]
    if url[0] == "/"
      # relative redirect
      uri = Addressable::URI.parse(@url)
      url = uri.scheme + "://" + uri.host + url
    elsif /^https?:\/\/./ !~ url
      raise("bad redirect: #{url}")
    end
    Addressable::URI.parse(url).normalize.to_s # Some redirects do not url encode properly, such as http://amzn.to/2aDg49F
  end

  def redirect_same_origin?
    return false if !redirect?
    uri = Addressable::URI.parse(@url).normalize
    new_uri = Addressable::URI.parse(redirect_url).normalize
    uri.origin == new_uri.origin
  end
end

class HTTPError < StandardError
  def initialize(obj)
    @obj = obj
  end

  def request
    @obj
  end

  def data
    @obj.json
  end

  def message
    if @obj.is_a?(HTTPResponse)
      "#{@obj.code}: #{@obj.body}"
    else
      @obj.inspect
    end
  end
end
