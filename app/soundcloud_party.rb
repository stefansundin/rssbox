# https://developers.soundcloud.com/docs/api/reference

class SoundcloudParty
  include HTTParty
  base_uri "https://api.soundcloud.com"
  default_params client_id: ENV["SOUNDCLOUD_CLIENT_ID"]
  format :json
end

class SoundcloudError < PartyError; end

error SoundcloudError do |e|
  status 503
  "There was a problem talking to Soundcloud."
end
