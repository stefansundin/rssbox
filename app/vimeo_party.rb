# https://developer.vimeo.com/api/start

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
  vimeo = VimeoParty.post("/oauth/authorize/client", basic_auth: { username: ENV["VIMEO_CLIENT_ID"], password: ENV["VIMEO_CLIENT_SECRET"] }, body: { grant_type: "client_credentials", scope: "public" })
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
