# https://www.mixcloud.com/developers/

class MixcloudParty
  include HTTParty
  base_uri "https://api.mixcloud.com"
  format :json
end

class MixcloudError < PartyError; end

error MixcloudError do |e|
  status 503
  "There was a problem talking to Mixcloud."
end
