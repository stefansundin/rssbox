# https://www.instagram.com/developer/endpoints/

class InstagramParty < HTTP
  BASE_URL = "https://www.instagram.com"
  PARAMS = "__a=1"
end

class InstagramError < PartyError; end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram."
end
