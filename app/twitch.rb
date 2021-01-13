# frozen_string_literal: true
# https://dev.twitch.tv/docs/api/

module App
  class TwitchError < HTTPError; end

  class Twitch < HTTP
    BASE_URL = "https://api.twitch.tv/helix"
    HEADERS = {
      "Client-ID" => ENV["TWITCH_CLIENT_ID"],
    }
    ERROR_CLASS = TwitchError
  end

  class TwitchToken < HTTP
    BASE_URL = "https://api.twitch.tv/api"
    HEADERS = {
      "Client-ID" => ENV["TWITCHTOKEN_CLIENT_ID"],
    }
    ERROR_CLASS = TwitchError
  end
end

error App::TwitchError do |e|
  status 503
  "There was a problem talking to Twitch. Please try again in a moment."
end
