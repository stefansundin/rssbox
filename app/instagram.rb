# frozen_string_literal: true
# https://www.instagram.com/developer/endpoints/

class InstagramError < HTTPError; end

class Instagram < HTTP
  BASE_URL = "https://www.instagram.com"
  PARAMS = "__a=1"
  ERROR_CLASS = InstagramError

  @@cache = {}

  def self.get_post(id)
    return @@cache[id] if @@cache[id]
    value = $redis.hget("instagram", id)
    if value
      @@cache[id] = JSON.parse(value)
      return @@cache[id]
    end

    response = Instagram.get("/p/#{id}/")
    raise(InstagramError, response) if !response.success?
    post = response.json["graphql"]["shortcode_media"]

    @@cache[id] = if post["__typename"] == "GraphSidecar"
      post["edge_sidecar_to_children"]["edges"].map do |edge|
        edge["node"].pluck(:is_video, :display_url, :video_url)
      end
    else
      # This isn't really used
      post.pluck(:is_video, :display_url, :video_url)
    end

    $redis.hset("instagram", id, @@cache[id].to_json)
    return @@cache[id]
  end
end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram. Please try again in a moment."
end
