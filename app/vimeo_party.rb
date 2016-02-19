# https://developer.vimeo.com/api/start
require "base64"

class VimeoParty
  include HTTParty
  base_uri "https://api.vimeo.com"
  format :json
end

class VimeoError < PartyError; end

error VimeoError do |e|
  status 503
  "There was a problem talking to Vimeo."
end



if !ENV["VIMEO_ACCESS_TOKEN"] and ENV["VIMEO_CLIENT_ID"] and ENV["VIMEO_CLIENT_SECRET"]
  # vimeo = VimeoParty.post("/oauth/authorize/client", headers: { Authorization: "basic #{Base64.encode64("#{ENV["VIMEO_CLIENT_ID"]}:#{ENV["VIMEO_CLIENT_SECRET"]}").gsub("\n","")}" }, body: { grant_type: "client_credentials", scope: "public" })
  vimeo = VimeoParty.post("/oauth/authorize/client", basic_auth: { username: ENV["VIMEO_CLIENT_ID"], password: ENV["VIMEO_CLIENT_SECRET"] }, body: { grant_type: "client_credentials", scope: "public" })
  # binding.pry
  if vimeo.success?
    ENV["VIMEO_ACCESS_TOKEN"] = vimeo.parsed_response["access_token"]
    puts "Please set VIMEO_ACCESS_TOKEN=#{ENV["VIMEO_ACCESS_TOKEN"]}"
  end
end

if ENV["VIMEO_ACCESS_TOKEN"]
  class VimeoParty
    headers Authorization: "bearer #{ENV["VIMEO_ACCESS_TOKEN"]}"
  end
end
