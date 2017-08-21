# https://developer.dailymotion.com/api

class DailymotionParty < HTTP
  BASE_URL = "https://api.dailymotion.com"
end

class DailymotionError < PartyError; end

error DailymotionError do |e|
  status 503
  "There was a problem talking to Dailymotion."
end
