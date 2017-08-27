# https://github.com/justintv/Twitch-API/

class Twitch < HTTP
  BASE_URL = "https://api.twitch.tv"
  HEADERS = {
    "Accept": "application/vnd.twitchtv.v3+json",
    "Client-ID": ENV["TWITCH_CLIENT_ID"],
  }
end

class TwitchError < HTTPError; end

error TwitchError do |e|
  status 503
  "There was a problem talking to Twitch."
end
