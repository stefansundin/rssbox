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
        next if response.code == 404
        raise(InstagramError, response) if !response.success? || !response.json
        data = response.json
        if data.has_key?("graphql")
          # response when not logged in
          post = data["graphql"]["shortcode_media"]

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
        else
          # response when logged in with INSTAGRAM_SESSIONID
          post = data["items"][0]

          nodes = (post["carousel_media"] || [post]).map do |media|
            {
              "is_video" => (media["media_type"] == 2),
              "display_url" => media["image_versions2"]["candidates"][0]["url"],
              "video_url" => media&.[]("video_versions")&.[](0)&.[]("url"),
            }
          end

          {
            "owner" => {
              "id" => post["user"]["pk"],
              "username" => post["user"]["username"],
            },
            "taken_at_timestamp" => post["taken_at"],
            "text" => post&.[]("caption")&.[]("text"),
            "nodes" => nodes,
          }.to_json
        end
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
  "Instagram is ratelimited. For more information, see https://github.com/stefansundin/rssbox/issues/39"
end
