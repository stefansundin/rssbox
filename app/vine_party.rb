# No public API documentation

class VineParty
  include HTTParty
  base_uri "https://vine.co/api"
  headers 'x-vine-client' => 'vinewww/2.0'
  format :json
end

class VineError < PartyError; end

error VineError do |e|
  status 503
  "There was a problem talking to Vine."
end
