# https://dev.twitter.com/rest/reference/get/statuses/user_timeline

class Twitter < HTTP
  BASE_URL = "https://api.twitter.com/1.1"
  HEADERS = {
    "Authorization": "Bearer #{ENV["TWITTER_ACCESS_TOKEN"]}",
  }
end

class TwitterError < HTTPError; end

error TwitterError do |e|
  status 503
  "There was a problem talking to Twitter."
end
