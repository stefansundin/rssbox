# frozen_string_literal: true

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

  @@cache = {}

  def self.get(url, options={headers: {}})
    options ||= {}
    options[:headers] ||= {}
    response = super(url, options)
    if response.code == 403
      raise(InstagramTokenError, response)
    elsif response.code == 429
      raise(InstagramRatelimitError, response)
    end
    response
  end

  def self.get_post(id, opts={})
    return @@cache[id] if @@cache[id]
    value = $redis.get("instagram:#{id}")
    if value
      @@cache[id] = JSON.parse(value)
      return @@cache[id]
    end

    response = Instagram.get("/p/#{id}/", opts)
    raise(InstagramError, response) if !response.success? || !response.json
    post = response.json["graphql"]["shortcode_media"]

    @@cache[id] = if post["__typename"] == "GraphSidecar"
      post["edge_sidecar_to_children"]["edges"].map do |edge|
        edge["node"].slice("is_video", "display_url", "video_url")
      end
    else
      # This isn't really used
      post.slice("is_video", "display_url", "video_url")
    end

    $redis.set("instagram:#{id}", @@cache[id].to_json)
    return @@cache[id]
  end
end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram. Please try again in a moment."
end

error InstagramRatelimitError do |e|
  status 429
  "There are too many requests going to Instagram right now. Someone is probably abusing this service. PLEASE SLOW DOWN!"
end
