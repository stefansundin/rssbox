# frozen_string_literal: true
# http://ustream.github.io/api-docs/broadcasting-api/channel.html

class UstreamError < HTTPError; end

class Ustream < HTTP
  BASE_URL = "https://api.ustream.tv"
  ERROR_CLASS = UstreamError
end

error UstreamError do |e|
  status 503
  "There was a problem talking to Ustream. Please try again in a moment."
end
