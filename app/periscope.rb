# No public API documentation

class PeriscopeError < HTTPError; end

class Periscope < HTTP
  BASE_URL = "https://api.periscope.tv/api/v2"
  ERROR_CLASS = PeriscopeError

  def self.get_broadcasts(user_id)
    response = get("https://www.periscope.tv/cnn")
    raise ERROR_CLASS.new(response) if !response.success?
    doc = Nokogiri::HTML(response.body)
    data = doc.at("div#page-container")["data-store"]
    json = JSON.parse(data)
    session_id = json["SessionToken"]["public"]["broadcastHistory"]["token"]["session_id"]
    get("/getUserBroadcastsPublic", query: { user_id: user_id, session_id: session_id })
  end
end

error PeriscopeError do |e|
  status 503
  "There was a problem talking to Periscope. Please try again in a moment."
end
