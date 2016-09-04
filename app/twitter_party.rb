# https://dev.twitter.com/rest/reference/get/statuses/user_timeline

class TwitterParty
  include HTTParty
  base_uri "https://api.twitter.com/1.1"
  headers Authorization: "Bearer #{ENV["TWITTER_ACCESS_TOKEN"]}"
  format :json
end

class TwitterError < PartyError; end

error TwitterError do |e|
  status 503
  "There was a problem talking to Twitter."
end
