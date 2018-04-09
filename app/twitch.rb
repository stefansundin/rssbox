# frozen_string_literal: true
# https://github.com/justintv/Twitch-API/

class TwitchError < HTTPError; end

class Twitch < HTTP
  BASE_URL = "https://api.twitch.tv/kraken"
  HEADERS = {
    "Accept" => "application/vnd.twitchtv.v3+json",
    "Client-ID" => ENV["TWITCH_CLIENT_ID"],
  }
  ERROR_CLASS = TwitchError
end

class TwitchToken < HTTP
  BASE_URL = "https://api.twitch.tv/api"
  HEADERS = {
    "Client-ID" => ENV["TWITCH_CLIENT_ID"],
  }
  ERROR_CLASS = TwitchError
end

error TwitchError do |e|
  status 503
  "There was a problem talking to Twitch. Please try again in a moment."
end
