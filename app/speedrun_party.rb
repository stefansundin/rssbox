# https://github.com/speedruncom/api/tree/master/version1

class SpeedrunParty
  include HTTParty
  base_uri "https://www.speedrun.com/api/v1"
  format :json

  @@cache = {}

  def self.resolve_id(type, id)
    @@cache[type] ||= {}
    return @@cache[type][id] if @@cache[type][id]
    value = $redis.hget("speedrun", "#{type}:#{id}")
    if value
      @@cache[type][id] = if type == "level-subcategories"
        JSON.parse(value)
      else
        value
      end
      return @@cache[type][id]
    end

    if type == "game"
      response = SpeedrunParty.get("/games/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      redis_value = value = response.parsed_response["data"]["names"]["international"]
    elsif type == "level-subcategories"
      response = SpeedrunParty.get("/levels/#{id}/variables")
      raise SpeedrunError.new(response) if !response.success?
      value = response.parsed_response["data"].select { |var| var["is-subcategory"] }.map do |var|
        [
          var["id"],
          var["values"]["values"].map do |id, val|
            [id, val["label"]]
          end.to_h
        ]
      end.to_h
      redis_value = value.to_json
    end

    $redis.hset("speedrun", "#{type}:#{id}", redis_value)
    @@cache[type][id] = value
    return value
  end
end

class SpeedrunError < PartyError; end

error SpeedrunError do |e|
  status 503
  "There was a problem talking to speedrun.com."
end
