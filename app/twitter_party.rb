# https://dev.twitter.com/rest/reference/get/statuses/user_timeline

class TwitterParty < HTTP
  BASE_URL = "https://api.twitter.com/1.1"
  HEADERS = {
    "Authorization": "Bearer #{ENV["TWITTER_ACCESS_TOKEN"]}",
  }
end

class TwitterError < PartyError; end

error TwitterError do |e|
  status 503
  "There was a problem talking to Twitter."
end
