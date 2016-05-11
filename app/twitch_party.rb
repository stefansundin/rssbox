# https://github.com/justintv/Twitch-API/

class TwitchParty
  include HTTParty
  base_uri "https://api.twitch.tv/kraken"
  headers "Client-ID": ENV["TWITCH_CLIENT_ID"]
  headers Accept: "application/vnd.twitchtv.v3+json"
  format :json
end

class TwitchError < PartyError; end

error TwitchError do |e|
  status 503
  "There was a problem talking to Twitch."
end
