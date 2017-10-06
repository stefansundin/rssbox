# frozen_string_literal: true
# https://www.instagram.com/developer/endpoints/

class InstagramError < HTTPError; end

class Instagram < HTTP
  BASE_URL = "https://www.instagram.com"
  PARAMS = "__a=1"
  ERROR_CLASS = InstagramError
end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram. Please try again in a moment."
end
