# https://developer.vimeo.com/api/start

class VimeoError < HTTPError; end

class Vimeo < HTTP
  BASE_URL = "https://api.vimeo.com"
  HEADERS = {
    "Authorization": "bearer #{ENV["VIMEO_ACCESS_TOKEN"]}",
  }
  ERROR_CLASS = VimeoError
end

error VimeoError do |e|
  status 503
  "There was a problem talking to Vimeo. Please try again in a moment."
end
