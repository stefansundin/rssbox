class InstagramParty
  include HTTParty
  base_uri "https://api.instagram.com/v1"
  default_params client_id: ENV["INSTAGRAM_CLIENT_ID"], client_secret: ENV["INSTAGRAM_CLIENT_SECRET"]
  format :json
end

class InstagramError < PartyError; end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram."
end
