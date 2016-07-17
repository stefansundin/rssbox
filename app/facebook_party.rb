# https://developers.facebook.com/docs/graph-api/reference/

class FacebookParty
  include HTTParty
  base_uri "https://graph.facebook.com/v2.7"
  default_params access_token: "#{ENV["FACEBOOK_APP_ID"]}|#{ENV["FACEBOOK_APP_SECRET"]}"
  format :json

  def self.batch(ids, query={})
    qs = "?" + query.map { |k,v| "#{k}=#{v}" }.join("&")
    response = post("/", query: { batch: ids.map { |id| { method: "GET", relative_url: id.to_s+qs } }.to_json, include_headers: false })
    response.parsed_response.map { |item| JSON.parse(item["body"]) }.map { |item| [item["id"], item.except("id")] }.to_h
  end
end

class FacebookError < PartyError; end

error FacebookError do |e|
  status 503
  "There was a problem talking to Facebook."
end
