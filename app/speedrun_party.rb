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
      @@cache[type][id] = value
      return value
    end

    value = if type == "game"
      response = SpeedrunParty.get("/games/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      response.parsed_response["data"]["names"]["international"]
    end

    $redis.hset("speedrun", "#{type}:#{id}", value)
    @@cache[type][id] = value
    return value
  end
end

class SpeedrunError < PartyError; end

error SpeedrunError do |e|
  status 503
  "There was a problem talking to speedrun.com."
end
