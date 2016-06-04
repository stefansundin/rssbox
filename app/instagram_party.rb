# https://www.instagram.com/developer/endpoints/

class InstagramParty
  include HTTParty
  base_uri "https://instagram.com"
  default_params __a: "1"
  format :json
end

class InstagramError < PartyError; end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram."
end
