# https://api.imgur.com/endpoints

class ImgurParty < HTTP
  BASE_URL = "https://api.imgur.com/3"
  HEADERS = {
    "Authorization": "Client-ID #{ENV["IMGUR_CLIENT_ID"]}",
  }
end

class ImgurError < PartyError; end

error ImgurError do |e|
  status 503
  "There was a problem talking to Imgur."
end
