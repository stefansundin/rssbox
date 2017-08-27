# https://www.mixcloud.com/developers/

class Mixcloud < HTTP
  BASE_URL = "https://api.mixcloud.com"
end

class MixcloudError < HTTPError; end

error MixcloudError do |e|
  status 503
  "There was a problem talking to Mixcloud."
end
