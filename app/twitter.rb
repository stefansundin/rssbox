# frozen_string_literal: true
# https://dev.twitter.com/rest/reference/get/statuses/user_timeline

class TwitterError < HTTPError; end

class Twitter < HTTP
  BASE_URL = "https://api.twitter.com/1.1"
  HEADERS = {
    "Authorization" => "Bearer #{ENV["TWITTER_ACCESS_TOKEN"]}",
  }
  ERROR_CLASS = TwitterError
end

error TwitterError do |e|
  status 503
  "There was a problem talking to Twitter. Please try again in a moment."
end
