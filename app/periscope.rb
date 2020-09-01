# frozen_string_literal: true
# No public API documentation

class PeriscopeError < HTTPError; end

class Periscope < HTTP
  BASE_URL = "https://api.periscope.tv/api/v2"
  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:80.0) Gecko/20100101 Firefox/80.0",
  }
  ERROR_CLASS = PeriscopeError

  # The session_id is valid for one hour
  @@session_id = nil

  def self.get_broadcasts(user_id)
    if @@session_id
      response = get("/getUserBroadcastsPublic", query: { user_id: user_id, session_id: @@session_id })
      if response.success?
        return response
      end
    end
    response = get("https://www.periscope.tv/cnn")
    raise(ERROR_CLASS, response) if !response.success?
    doc = Nokogiri::HTML(response.body)
    data = doc.at("div#page-container")["data-store"]
    json = JSON.parse(data)
    @@session_id = json["SessionToken"]["public"]["broadcastHistory"]["token"]["session_id"]
    get("/getUserBroadcastsPublic", query: { user_id: user_id, session_id: @@session_id })
  end
end

error PeriscopeError do |e|
  status 503
  "There was a problem talking to Periscope. Please try again in a moment."
end
