# https://developers.facebook.com/docs/graph-api/reference/

class FacebookParty < HTTP
  BASE_URL = "https://graph.facebook.com/v2.8"
  PARAMS = "access_token=#{ENV["FACEBOOK_APP_ID"]}|#{ENV["FACEBOOK_APP_SECRET"]}"
end

class FacebookError < PartyError; end

error FacebookError do |e|
  status 503
  "There was a problem talking to Facebook."
end
