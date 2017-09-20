# https://docs.vid.me/

class VidmeError < HTTPError; end

class Vidme < HTTP
  BASE_URL = "https://api.vid.me"
  ERROR_CLASS = VidmeError
end

error VidmeError do |e|
  status 503
  "There was a problem talking to Vidme. Please try again in a moment."
end
