# frozen_string_literal: true

class InstagramError < HTTPError; end
class InstagramTokenError < InstagramError; end

class Instagram < HTTP
  BASE_URL = "https://www.instagram.com"
  PARAMS = "__a=1"
  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:65.0) Gecko/20100101 Firefox/65.0",
    "Cookie" => "ig_cb=1",
  }
  ERROR_CLASS = InstagramError

  @@cache = {}
  @@csrftoken = nil

  def self.get(url, options={headers: {}}, tokens={csrftoken: nil})
    if !tokens[:csrftoken] && !@@csrftoken
      response = HTTP.get("https://www.instagram.com/", headers: HEADERS)
      raise(InstagramTokenError, response) if !response.success?
      /csrftoken=(?<csrftoken>[A-Za-z0-9]+);/ =~ response.headers["set-cookie"].find { |c| /csrftoken=[A-Za-z0-9]+/.match?(c) }
      raise(InstagramTokenError, response) if !csrftoken
      @@csrftoken = csrftoken
    end
    options ||= {}
    options[:headers] ||= {}
    response = super(url, options)
    if response.code == 403
      raise(InstagramTokenError, response)
    end
    response
  end

  def self.get_post(id, opts={}, tokens={})
    return @@cache[id] if @@cache[id]
    value = $redis.get("instagram:#{id}")
    if value
      @@cache[id] = JSON.parse(value)
      return @@cache[id]
    end

    response = Instagram.get("/p/#{id}/", opts, tokens)
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
