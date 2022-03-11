# https://github.com/huyha85/opengraph_parser/pull/21

class RedirectFollower
  def resolve
    raise TooManyRedirects if redirect_limit < 0

    uri = Addressable::URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.inferred_port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    self.response = http.request_get(uri.request_uri, @headers)
    if response.kind_of?(Net::HTTPRedirection)
      self.url = redirect_url
      self.redirect_limit -= 1
      resolve
    end
    self.body = response.body
    self
  end
end
