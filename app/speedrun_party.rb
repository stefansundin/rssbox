# https://github.com/speedruncom/api/tree/master/version1

class SpeedrunParty
  include HTTParty
  base_uri "https://www.speedrun.com/api/v1"
  format :json

  def self.resolve_id(type, id)
    value = $redis.hget("speedrun", "#{type}:#{id}")
    return value if value

    value = if type == "game"
      response = SpeedrunParty.get("/games/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      response.parsed_response["data"]["names"]["international"]
    elsif type == "category"
      response = SpeedrunParty.get("/categories/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      response.parsed_response["data"]["name"]
    elsif type == "category_link"
      response = SpeedrunParty.get("/categories/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      response.parsed_response["data"]["weblink"].partition("#")[2]
    elsif type == "user"
      response = SpeedrunParty.get("/users/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      response.parsed_response["data"]["names"]["international"]
    elsif type == "platform"
      response = SpeedrunParty.get("/platforms/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      response.parsed_response["data"]["name"]
    elsif type == "region"
      response = SpeedrunParty.get("/regions/#{id}")
      raise SpeedrunError.new(response) if !response.success?
      response.parsed_response["data"]["name"]
    end

    $redis.hset("speedrun", "#{type}:#{id}", value)
    return value
  end
end

class SpeedrunError < PartyError; end

error SpeedrunError do |e|
  status 503
  "There was a problem talking to speedrun.com."
end
