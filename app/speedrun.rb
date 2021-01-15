# frozen_string_literal: true
# https://github.com/speedruncom/api/tree/master/version1

module App
  class SpeedrunError < HTTPError; end

  class Speedrun < HTTP
    BASE_URL = "https://www.speedrun.com/api/v1"
    HEADERS = {
      "User-Agent" => "rssbox",
    }
    ERROR_CLASS = SpeedrunError

    def self.resolve_id(type, id)
      value, _ = App::Cache.cache("speedrun.#{type}.#{id}", 24*60*60, 60) do
        if type == "game"
          response = Speedrun.get("/games/#{id}")
          raise(SpeedrunError, response) if !response.success?
          response.json["data"]["names"]["international"]
        else
          raise("unsupported type")
        end
      end
      value
    end
  end
end

error App::SpeedrunError do |e|
  status 422
  "There was a problem talking to speedrun.com. Please try again in a moment."
end
