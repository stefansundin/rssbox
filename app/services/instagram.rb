# frozen_string_literal: true

module App
  class InstagramError < HTTPError; end
  class InstagramRatelimitError < HTTPError; end
  class InstagramTokenError < InstagramError; end

  class Instagram < HTTP
    BASE_URL = "https://www.instagram.com"
    HEADERS = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:137.0) Gecko/20100101 Firefox/137.0",
      "Cookie" => "ig_cb=1",
      "X-CSRFToken" => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", # This must be present but doesn't seem to be validated?!
    }
    ERROR_CLASS = InstagramError

    if ENV.has_key?("INSTAGRAM_SESSIONID")
      sessionid = ENV["INSTAGRAM_SESSIONID"]
      if sessionid.include?(":")
        sessionid = CGI.escape(sessionid)
      end
      HEADERS["Cookie"] += "; sessionid=#{sessionid}"
    end

    def self.get_post(id)
      data, _ = Cache.cache("instagram.post", id, 7*24*60*60, 60*60) do
        response = App::Instagram.post("/graphql/query/",
          "variables=%7B%22shortcode%22%3A%22#{id}%22%2C%22fetch_tagged_user_count%22%3Anull%2C%22hoisted_comment_id%22%3Anull%2C%22hoisted_reply_id%22%3Anull%7D&doc_id=8845758582119845",
          {
            headers: {
              "Content-Type" => "application/x-www-form-urlencoded",
            }
          }
        )
        next nil if response.code == 401 && response.body.include?('"Please wait a few minutes before you try again."')
        raise(InstagramError, response) if !response.success? || !response.json

        data = response.json["data"]["xdt_shortcode_media"]
        {
          "owner" => data["owner"].slice("id", "username"),
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
