# frozen_string_literal: true

class Hash
  def to_querystring
    self.select { |k,v| v.is_a?(String) }.map { |k,v| "#{k}=#{CGI.escape(v)}" }.join("&")
  end

  def pluck(*keys)
    self.select { |k,v| keys.include?(k.to_sym) or keys.include?(k.to_s) }
  end

  def val(*keys)
    self.pluck(*keys).values
  end
end
