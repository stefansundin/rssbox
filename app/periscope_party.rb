# No public API documentation

class PeriscopeParty
  include HTTParty
  base_uri "https://api.periscope.tv/api/v2"
  format :json

  def self.get_broadcasts(user_id)
    response = HTTParty.get("https://www.periscope.tv/cnn", format: :plain)
    doc = Nokogiri::HTML(response.body)
    data = doc.at("div#page-container")["data-store"]
    json = JSON.parse(data)
    session_id = json["SessionToken"]["broadcastHistory"]["token"]["session_id"]
    get("/getUserBroadcastsPublic", query: { user_id: user_id, session_id: session_id })
  end
end

class PeriscopeError < PartyError; end

error PeriscopeError do |e|
  status 503
  "There was a problem talking to Periscope."
end
