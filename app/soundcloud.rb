# frozen_string_literal: true
# https://developers.soundcloud.com/docs/api/reference

module App
  class SoundcloudError < HTTPError; end

  class Soundcloud < HTTP
    BASE_URL = "https://api-v2.soundcloud.com"
    PARAMS = "client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}"
    ERROR_CLASS = SoundcloudError
  end
end

error App::SoundcloudError do |e|
  status 503
  "There was a problem talking to SoundCloud. Please try again in a moment."
end
