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

    @@cache = {}

    def self.resolve_id(type, id)
      @@cache[type] ||= {}
      return @@cache[type][id] if @@cache[type][id]
      value = $redis.get("speedrun:#{type}:#{id}")
      if value
        @@cache[type][id] = value
        return value
      end

      if type == "game"
        response = get("/games/#{id}")
        raise(SpeedrunError, response) if !response.success?
        value = response.json["data"]["names"]["international"]
      else
        raise("unsupported type")
      end

      $redis.set("speedrun:#{type}:#{id}", value)
      @@cache[type][id] = value
      return value
    end
  end
end

error App::SpeedrunError do |e|
  status 422
  "There was a problem talking to speedrun.com. Please try again in a moment."
end
