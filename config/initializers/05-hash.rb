class Hash
  def to_querystring
    self.map { |k,v| "#{k}=#{v}" }.join("&")
  end
end
