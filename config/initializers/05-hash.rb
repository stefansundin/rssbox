class Hash
  def to_querystring
    self.map { |k,v| "#{k}=#{CGI.escape(v)}" }.join("&")
  end
end
