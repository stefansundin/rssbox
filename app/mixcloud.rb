# frozen_string_literal: true
# https://www.mixcloud.com/developers/

class MixcloudError < HTTPError; end

class Mixcloud < HTTP
  BASE_URL = "https://api.mixcloud.com"
  ERROR_CLASS = MixcloudError
end

error MixcloudError do |e|
  status 503
  "There was a problem talking to Mixcloud. Please try again in a moment."
end
