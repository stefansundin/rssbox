class YoutubeParty
  include HTTParty
  base_uri "https://www.googleapis.com/youtube/v3"
  default_params key: ENV["GOOGLE_API_KEY"]
  format :json
end

class YoutubeError < PartyError; end

error YoutubeError do |e|
  status 503
  "There was a problem talking to YouTube."
end
