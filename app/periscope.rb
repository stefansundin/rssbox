# No public API documentation

class Periscope < HTTP
  BASE_URL = "https://api.periscope.tv/api/v2"

  def self.get_broadcasts(user_id)
    response = HTTP.get("https://www.periscope.tv/cnn")
    doc = Nokogiri::HTML(response.body)
    data = doc.at("div#page-container")["data-store"]
    json = JSON.parse(data)
    session_id = json["SessionToken"]["public"]["broadcastHistory"]["token"]["session_id"]
    get("/getUserBroadcastsPublic", query: { user_id: user_id, session_id: session_id })
  end
end

class PeriscopeError < HTTPError; end

error PeriscopeError do |e|
  status 503
  "There was a problem talking to Periscope."
end
