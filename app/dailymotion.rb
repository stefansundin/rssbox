# https://developer.dailymotion.com/api

class Dailymotion < HTTP
  BASE_URL = "https://api.dailymotion.com"
end

class DailymotionError < HTTPError; end

error DailymotionError do |e|
  status 503
  "There was a problem talking to Dailymotion."
end
