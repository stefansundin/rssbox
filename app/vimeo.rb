# https://developer.vimeo.com/api/start

class Vimeo < HTTP
  BASE_URL = "https://api.vimeo.com"
  HEADERS = {
    "Authorization": "bearer #{ENV["VIMEO_ACCESS_TOKEN"]}",
  }
end

class VimeoError < HTTPError; end

error VimeoError do |e|
  status 503
  "There was a problem talking to Vimeo."
end
