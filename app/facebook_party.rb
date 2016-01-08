# https://developers.facebook.com/docs/graph-api/reference/

class FacebookParty
  include HTTParty
  base_uri "https://graph.facebook.com/v2.3"
  default_params access_token: "#{ENV["FACEBOOK_APP_ID"]}|#{ENV["FACEBOOK_APP_SECRET"]}"
  format :json
end

class FacebookError < PartyError; end

error FacebookError do |e|
  status 503
  "There was a problem talking to Facebook."
end
