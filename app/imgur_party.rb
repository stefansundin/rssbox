# https://api.imgur.com/endpoints

class ImgurParty
  include HTTParty
  base_uri "https://api.imgur.com/3"
  headers Authorization: "Client-ID #{ENV["IMGUR_CLIENT_ID"]}"
  format :json
end

class ImgurError < PartyError; end

error ImgurError do |e|
  status 503
  "There was a problem talking to Imgur."
end
