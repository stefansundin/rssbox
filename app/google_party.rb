# https://developers.google.com/youtube/v3/docs/
# https://developers.google.com/+/web/api/rest/

class GoogleParty
  include HTTParty
  base_uri "https://www.googleapis.com"
  default_params key: ENV["GOOGLE_API_KEY"]
  format :json
end

class GoogleError < PartyError; end

error GoogleError do |e|
  status 503
  "There was a problem talking to Google."
end
