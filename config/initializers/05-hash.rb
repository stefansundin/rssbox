# frozen_string_literal: true

class Hash
  def to_querystring
    self.select { |k,v| v.is_a?(String) }.map { |k,v| "#{k}=#{CGI.escape(v)}" }.join("&")
  end
end
