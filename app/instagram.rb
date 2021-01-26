# frozen_string_literal: true

module App
  class InstagramError < HTTPError; end
  class InstagramRatelimitError < HTTPError; end
  class InstagramTokenError < InstagramError; end

  class Instagram < HTTP
    BASE_URL = "https://www.instagram.com"
    PARAMS = "__a=1"
    HEADERS = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:80.0) Gecko/20100101 Firefox/80.0",
      "Cookie" => "ig_cb=1",
    }
    ERROR_CLASS = InstagramError

    if ENV.has_key?("INSTAGRAM_SESSIONID")
      sessionid = ENV["INSTAGRAM_SESSIONID"]
      if sessionid.include?(":")
        sessionid = CGI.escape(sessionid)
      end
      HEADERS["Cookie"] += "; sessionid=#{sessionid}"
    end

    def self.get(url, options={})
      response = super(url, options)
      if response.code == 403
        raise(InstagramTokenError, response)
      elsif response.code == 429 || response.code == 302
        raise(InstagramRatelimitError, response)
      end
      response
    end

    def self.get_post(id)
      data, _ = Cache.cache("instagram.post", id, 7*24*60*60, 60*60) do
        response = get("/p/#{id}/")
        raise(InstagramError, response) if !response.success? || !response.json
        post = response.json["graphql"]["shortcode_media"]

        if post.has_key?("edge_sidecar_to_children")
          nodes = post["edge_sidecar_to_children"]["edges"].map do |edge|
            edge["node"].slice("is_video", "display_url", "video_url")
          end
        else
          nodes = [ post.slice("is_video", "display_url", "video_url") ]
        end
        text = post["edge_media_to_caption"]["edges"][0]["node"]["text"] if post["edge_media_to_caption"]["edges"][0]

        {
          "owner" => post["owner"].slice("id", "username"),
          "taken_at_timestamp" => post["taken_at_timestamp"],
          "text" => text,
          "nodes" => nodes,
        }.to_json
      end
      return nil if data.nil?
      return JSON.parse(data)
    end
  end
end

error App::InstagramError do |e|
  status 422
  "There was a problem talking to Instagram. Please try again in a moment."
end

error App::InstagramRatelimitError do |e|
  status 429
  "There are too many requests going to Instagram right now. Someone is probably abusing this service. PLEASE SLOW DOWN!"
end
