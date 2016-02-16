# https://developer.dailymotion.com/api

class DailymotionParty
  include HTTParty
  base_uri "https://api.dailymotion.com"
  format :json
end

class DailymotionError < PartyError; end

error DailymotionError do |e|
  status 503
  "There was a problem talking to Dailymotion."
end
