# frozen_string_literal: true

class HTTP
  def self.get(url, options={})
    relative_url = (url[0] == "/")

    if defined?(self::BASE_URL) && relative_url
      url = self::BASE_URL+url
    end

    if defined?(self::PARAMS) && relative_url
      if url["?"]
        url += "&"+self::PARAMS
      else
        url += "?"+self::PARAMS
      end
    end

    uri = Addressable::URI.parse(url).normalize

    if options.has_key?(:query)
      if uri.query_values.nil?
        uri.query_values = options[:query]
      else
        uri.query_values = uri.query_values.merge(options[:query])
      end
    end

    opts = {
      use_ssl: uri.scheme == "https",
      open_timeout: 10,
      read_timeout: 10,
    }
    Net::HTTP.start(uri.host, uri.port, opts) do |http|
      headers = {}
      headers.merge!(self::HEADERS) if defined?(self::HEADERS) && relative_url
      headers.merge!(options[:headers]) if options.has_key?(:headers)
      response = http.request_get(uri.request_uri, headers)
      $metrics[:requests].increment(labels: { service: self.to_s.downcase, response_code: response.code })
      return HTTPResponse.new(response, uri.to_s)
    end
  rescue => e
    self::ERROR_CLASS ||= HTTPError
    raise(self::ERROR_CLASS, e)
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
    @response.to_hash
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
  def initialize(obj=nil)
    @obj = obj
  end

  def request
    @obj
  end

  def data
    @obj.json
  end

  def message
    msg = if @obj.is_a?(HTTPResponse)
      if @obj.redirect?
        "#{@obj.code}: #{@obj.headers["location"].join(", ")}"
      else
        "#{@obj.code}: #{@obj.body}"
      end
    else
      @obj.inspect
    end
    # If this function is called from Sinatra, then we want to truncate the message in order to cut down on log filesize
    if ENV["APP_ENV"] == "production" && caller_locations(1,1)[0].path.end_with?("/lib/sinatra/base.rb")
      msg[0...100]
    else
      msg
    end
  end
end
