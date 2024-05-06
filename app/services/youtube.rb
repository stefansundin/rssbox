# frozen_string_literal: true
# https://developers.google.com/youtube/v3/docs/

require_relative "google"

module App
  class YouTube < Google
    BASE_URL = "https://www.googleapis.com/youtube/v3"

    def self.is_short?(video_id)
      is_short, _ = App::Cache.cache("youtube.shorts", video_id, 7*24*60*60, 60) do
        url = "https://www.youtube.com/shorts/#{video_id}"
        uri = Addressable::URI.parse(url)
        opts = {
          use_ssl: uri.scheme == "https",
          open_timeout: 10,
          read_timeout: 10,
        }
        Net::HTTP.start(uri.host, uri.port, opts) do |http|
          response = http.request_get(uri.request_uri)
          $metrics[:requests_total].increment(labels: { service: "youtube", response_code: response.code })
          next (response.code == "200").to_i.to_s
        end
      rescue => e
        raise(self::ERROR_CLASS, e)
      end

      return is_short == "1"
    end
  end
end
