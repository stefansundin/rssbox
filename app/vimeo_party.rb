# https://developer.vimeo.com/api/start

class VimeoParty < HTTP
  BASE_URL = "https://api.vimeo.com"
  HEADERS = {
    "Authorization": "bearer #{ENV["VIMEO_ACCESS_TOKEN"]}",
  }
end

class VimeoError < PartyError; end

error VimeoError do |e|
  status 503
  "There was a problem talking to Vimeo."
end
