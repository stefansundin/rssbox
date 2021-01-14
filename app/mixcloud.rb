# frozen_string_literal: true
# https://www.mixcloud.com/developers/

module App
  class MixcloudError < HTTPError; end

  class Mixcloud < HTTP
    BASE_URL = "https://api.mixcloud.com"
    ERROR_CLASS = MixcloudError
  end
end

error App::MixcloudError do |e|
  status 422
  "There was a problem talking to Mixcloud. Please try again in a moment."
end
