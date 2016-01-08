# http://ustream.github.io/api-docs/broadcasting-api/channel.html

class UstreamParty
  include HTTParty
  base_uri "https://api.ustream.tv"
  format :json
end

class UstreamError < PartyError; end

error UstreamError do |e|
  status 503
  "There was a problem talking to Ustream."
end
