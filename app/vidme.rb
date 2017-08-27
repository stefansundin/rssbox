# https://docs.vid.me/

class Vidme < HTTP
  BASE_URL = "https://api.vid.me"
end

class VidmeError < HTTPError; end

error VidmeError do |e|
  status 503
  "There was a problem talking to Vidme."
end
