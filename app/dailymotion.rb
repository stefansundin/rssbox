# frozen_string_literal: true
# https://developer.dailymotion.com/api

module App
  class DailymotionError < HTTPError; end

  class Dailymotion < HTTP
    BASE_URL = "https://api.dailymotion.com"
    ERROR_CLASS = DailymotionError
  end
end

error App::DailymotionError do |e|
  status 503
  "There was a problem talking to Dailymotion. Please try again in a moment."
end
