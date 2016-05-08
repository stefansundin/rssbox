# https://developer.vimeo.com/api/start

class VimeoParty
  include HTTParty
  base_uri "https://api.vimeo.com"
  headers Authorization: "bearer #{ENV["VIMEO_ACCESS_TOKEN"]}"
  format :json
end

class VimeoError < PartyError; end

error VimeoError do |e|
  status 503
  "There was a problem talking to Vimeo."
end
