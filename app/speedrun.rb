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
        @@cache[type][id] = if type == "level-subcategories"
          JSON.parse(value)
        else
          value
        end
        return @@cache[type][id]
      end

      if type == "game"
        response = Speedrun.get("/games/#{id}")
        raise(SpeedrunError, response) if !response.success?
        redis_value = value = response.json["data"]["names"]["international"]
      elsif type == "level-subcategories"
        response = Speedrun.get("/levels/#{id}/variables")
        raise(SpeedrunError, response) if !response.success?
        value = response.json["data"].select { |var| var["is-subcategory"] }.to_h do |var|
          [
            var["id"],
            var["values"]["values"].to_h do |id, val|
              [id, val["label"]]
            end
          ]
        end
        redis_value = value.to_json
      end

      $redis.set("speedrun:#{type}:#{id}", redis_value)
      @@cache[type][id] = value
      return value
    end
  end
end

error App::SpeedrunError do |e|
  status 503
  "There was a problem talking to speedrun.com. Please try again in a moment."
end
