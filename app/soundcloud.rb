# https://developers.soundcloud.com/docs/api/reference

class SoundcloudError < HTTPError; end

class Soundcloud < HTTP
  BASE_URL = "https://api.soundcloud.com"
  PARAMS = "client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}"
  ERROR_CLASS = SoundcloudError
end

error SoundcloudError do |e|
  status 503
  "There was a problem talking to SoundCloud. Please try again in a moment."
end
