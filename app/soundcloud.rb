# https://developers.soundcloud.com/docs/api/reference

class Soundcloud < HTTP
  BASE_URL = "https://api.soundcloud.com"
  PARAMS = "client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}"
end

class SoundcloudError < HTTPError; end

error SoundcloudError do |e|
  status 503
  "There was a problem talking to Soundcloud."
end
