# frozen_string_literal: true
# https://www.instagram.com/developer/endpoints/

class InstagramError < HTTPError; end
class InstagramTokenError < InstagramError; end

class Instagram < HTTP
  BASE_URL = "https://www.instagram.com"
  PARAMS = "__a=1"
  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:59.0) Gecko/20100101 Firefox/59.0",
  }
  ERROR_CLASS = InstagramError

  @@cache = {}
  @@csrftoken = nil
  @@rhx_gis = nil

  def self.get(url, options={headers: {}, query: nil})
    if !@@csrftoken
      response = HTTP.get("https://www.instagram.com/", headers: HEADERS)
      raise(InstagramTokenError, response) if !response.success?
      /csrftoken=(?<csrftoken>[A-Za-z0-9]+);/ =~ response.headers["set-cookie"].find { |c| c.start_with?("csrftoken=") }
      /"rhx_gis":"(?<rhx_gis>[a-z0-9]{32})"/ =~ response.body
      raise(InstagramTokenError, response) if !csrftoken || !rhx_gis
      @@csrftoken = csrftoken
      @@rhx_gis = rhx_gis
    end
    options ||= {}
    options[:headers] ||= {}
    options[:headers]["Cookie"] = "csrftoken=#{@@csrftoken}"
    options[:headers]["x-instagram-gis"] = Digest::MD5.hexdigest("#{@@rhx_gis}:#{url}")
    response = super(url, options)
    if response.code == 403
      @@csrftoken = nil
      @@rhx_gis = nil
      raise(InstagramTokenError, response)
    end
    response
  end

  def self.get_post(id, opts={})
    return @@cache[id] if @@cache[id]
    value = $redis.hget("instagram", id)
    if value
      @@cache[id] = JSON.parse(value)
      return @@cache[id]
    end

    response = Instagram.get("/p/#{id}/", opts)
    raise(InstagramError, response) if !response.success?
    post = response.json["graphql"]["shortcode_media"]

    @@cache[id] = if post["__typename"] == "GraphSidecar"
      post["edge_sidecar_to_children"]["edges"].map do |edge|
        edge["node"].slice("is_video", "display_url", "video_url")
      end
    else
      # This isn't really used
      post.slice("is_video", "display_url", "video_url")
    end

    $redis.hset("instagram", id, @@cache[id].to_json)
    return @@cache[id]
  end
end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram. Please try again in a moment."
end
