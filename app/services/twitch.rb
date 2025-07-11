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

  class TwitchGraphQL < HTTP
    BASE_URL = "https://gql.twitch.tv/gql"
    HEADERS = {
      "Client-ID" => ENV["TWITCHTOKEN_CLIENT_ID"],
      "Content-Type" => "application/json",
    }
    ERROR_CLASS = TwitchError

    def self.resolve_category_slug(slug)
      path, _ = Cache.cache("twitch.category", slug, 7*24*60*60, 60*60) do
        response = self.post(nil,
          {
            "query": "query category($slug: String!) { game(slug: $slug) { id name } }",
            "variables": { "slug": slug },
          }.to_json,
        )
        raise(TwitchError, response) if !response.success? || !response.json
        data = response.json["data"]["game"]
        next "Error: Can't find a category with that name." if data.nil?

        "#{data["id"]}/#{data["name"]}"
      end
      path
    end
  end
end

error App::TwitchError do |e|
  status 422
  "There was a problem talking to Twitch. Please try again in a moment."
end
