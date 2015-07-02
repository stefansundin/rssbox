class Hash
  def to_querystring
    # self.to_a.map { |x| "#{x[0]}=#{x[1]}" }.join("&")
    self.map { |k,v| "#{k}=#{v}" }.join("&")
  end
end
