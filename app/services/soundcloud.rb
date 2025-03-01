# frozen_string_literal: true
# https://developers.soundcloud.com/docs/api/reference

require "base64"

module App
  class SoundcloudError < HTTPError; end

  class Soundcloud < HTTP
    BASE_URL = "https://api.soundcloud.com"
    ERROR_CLASS = SoundcloudError

    def self.get(url, options={})
      access_token = App::Soundcloud.access_token
      options[:headers] ||= {}
      options[:headers]["Authorization"] = "Bearer #{access_token}"
      super(url, options)
    end

    def self.resolve(url)
      return nil if !url.start_with?("https://soundcloud.com/")
      uri = Addressable::URI.parse(url)
      return nil if uri.path.empty?

      api_uri, _ = App::Cache.cache("soundcloud.resolve", uri.path.downcase, 7*24*60*60, 60) do
        response = App::Soundcloud.get("/resolve", query: { url: "https://soundcloud.com#{uri.path}" })
        next if response.code != 302
        response.headers["location"]
      end

      return api_uri
    end

    def self.access_token
      return nil if !ENV["SOUNDCLOUD_CLIENT_ID"] || !ENV["SOUNDCLOUD_CLIENT_SECRET"]

      access_token, _ = App::Cache.cache("soundcloud", "access_token", 3560, 60) do
        url = "https://secure.soundcloud.com/oauth/token"
        uri = Addressable::URI.parse(url)
        opts = {
          use_ssl: uri.scheme == "https",
          open_timeout: 10,
          read_timeout: 10,
        }
        response = Net::HTTP.start(uri.host, uri.port, opts) do |http|
          credentials = Base64.strict_encode64("#{ENV["SOUNDCLOUD_CLIENT_ID"]}:#{ENV["SOUNDCLOUD_CLIENT_SECRET"]}")
          headers = {
            "Accept" => "application/json; charset=utf-8",
            "Authorization" => "Basic #{credentials}",
          }
          request = Net::HTTP::Post.new(uri.request_uri, headers)
          request.set_form_data(grant_type: "client_credentials")
          http.request(request)
        end
        raise(App::HTTPError, response) if !response.is_a?(Net::HTTPSuccess)

        json = JSON.parse(response.body)
        json["access_token"]
      end

      return access_token
    end
  end
end

error App::SoundcloudError do |e|
  status 422
  "There was a problem talking to SoundCloud. Please try again in a moment."
end
