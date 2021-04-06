# frozen_string_literal: true
# https://developers.soundcloud.com/docs/api/reference

module App
  class SoundcloudError < HTTPError; end

  class Soundcloud < HTTP
    BASE_URL = "https://api-v2.soundcloud.com"
    PARAMS = "client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}"
    ERROR_CLASS = SoundcloudError

    def self.resolve(url)
      return nil if !url.start_with?("https://soundcloud.com/")
      uri = Addressable::URI.parse(url)
      return nil if uri.path.empty?

      api_uri, _ = App::Cache.cache("soundcloud.resolve", uri.path.downcase, 7*24*60*60, 60) do
        response = App::Soundcloud.get("/resolve", query: { url: "https://soundcloud.com#{uri.path}" })
        next if response.code != 200
        response.json["uri"]
      end

      return api_uri
    end
  end
end

error App::SoundcloudError do |e|
  status 422
  "There was a problem talking to SoundCloud. Please try again in a moment."
end
