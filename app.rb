require "sinatra"
require "./config/application"
require "active_support/core_ext/string"

get "/" do
  erb :index
end

get "/go" do
  return "Insufficient parameters" if params[:q].empty?

  if /^https?:\/\/(www\.)?youtu(\.?be|be\.com)/ =~ params[:q]
    redirect "/youtube?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?facebook\.com/ =~ params[:q]
    redirect "/facebook?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?instagram\.com/ =~ params[:q]
    redirect "/instagram?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?soundcloud\.com/ =~ params[:q]
    redirect "/soundcloud?#{params.to_querystring}"
  else
    "Unknown service"
  end
end

get "/youtube" do
  return "Insufficient parameters" if params[:q].empty?

  if /youtube\.com\/channel\/(?<channel_id>UC[^\/\?#]+)/ =~ params[:q]
    # https://www.youtube.com/channel/UC4a-Gbdw7vOaccHmFo40b9g/videos
  elsif /youtube\.com\/user\/(?<user>[^\/\?#]+)/ =~ params[:q]
    # https://www.youtube.com/user/khanacademy/videos
  elsif /youtube\.com\/c\/(?<user>[^\/\?#]+)/ =~ params[:q]
    # https://www.youtube.com/c/khanacademy/videos
    # this query might return the wrong user, e.g. https://www.youtube.com/c/kawaiiguy and https://www.youtube.com/user/kawaiiguy are two different channels.
  elsif /youtube\.com\/.*[\?&]v=(?<video_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/watch?v=vVXbgbMp0oY&t=5s
  elsif /youtube\.com\/.*[\?&]list=(?<playlist_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/playlist?list=PL0QrZvg7QIgpoLdNFnEePRrU-YJfr9Be7
  elsif /youtube\.com\/(?<user>[^\/\?#]+)/ =~ params[:q]
    # https://www.youtube.com/khanacademy
  elsif /youtu\.be\/(?<video_id>[^\?#]+)/ =~ params[:q]
    # https://youtu.be/vVXbgbMp0oY?t=1s
  elsif /(?<channel_id>UC[^\/\?#]+)/ =~ params[:q]
    # it's a channel id
  else
    # it's probably a channel name
    user = params[:q]
  end

  if user
    response = HTTParty.get("https://www.googleapis.com/youtube/v3/channels", query: { part: "id", forUsername: user, key: ENV["GOOGLE_API_KEY"] }, format: :json)
    raise YoutubeError.new(response) if !response.success?

    if response.parsed_response["items"].length > 0
      channel_id = response.parsed_response["items"][0]["id"]
    end
  end

  if video_id
    response = HTTParty.get("https://www.googleapis.com/youtube/v3/videos", query: { part: "snippet", id: video_id, key: ENV["GOOGLE_API_KEY"] }, format: :json)
    raise YoutubeError.new(response) if !response.success?

    if response.parsed_response["items"].length > 0
      channel_id = response.parsed_response["items"][0]["snippet"]["channelId"]
    end
  end

  if channel_id
    redirect "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel_id}"
  elsif playlist_id
    redirect "https://www.youtube.com/feeds/videos.xml?playlist_id=#{playlist_id}"
  else
    "Could not find the channel. Sorry."
  end
end

get "/facebook" do
  return "Insufficient parameters" if params[:q].empty?

  if /facebook\.com\/pages\/[^\/]+\/(?<id>\d+)/ =~ params[:q]
    # https://www.facebook.com/pages/Lule%C3%A5-Sweden/106412259396611?fref=ts
  elsif /facebook\.com\/groups\/(?<id>\d+)/ =~ params[:q]
    # https://www.facebook.com/groups/223764997793315
  elsif /facebook\.com\/[^\/]+-(?<id>[\d]+)/ =~ params[:q]
    # https://www.facebook.com/TNG-Recuts-867357396651373/
  elsif /facebook\.com\/(?<id>[^\/\?#]+)/ =~ params[:q]
    # https://www.facebook.com/celldweller/info?tab=overview
  else
    id = params[:q]
  end

  response = HTTParty.get("https://graph.facebook.com/v2.3/#{id}", query: { access_token: "#{ENV["FACEBOOK_APP_ID"]}|#{ENV["FACEBOOK_APP_SECRET"]}" }, format: :json)
  return "Can't find a page with that name. Sorry." if response.code == 404
  raise FacebookError.new(response) if !response.success?

  data = response.parsed_response
  redirect "/facebook/#{data["id"]}/#{data["username"] || data["name"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
end

get "/facebook/download" do
  if /\/(?<id>\d+)/ =~ params[:url]
    # https://www.facebook.com/infectedmushroom/videos/10153430677732261/
    # https://www.facebook.com/infectedmushroom/videos/vb.8811047260/10153371214897261/?type=2&theater
  else
    id = params[:q]
  end

  response = HTTParty.get("https://graph.facebook.com/v2.3/#{id}", query: { access_token: "#{ENV["FACEBOOK_APP_ID"]}|#{ENV["FACEBOOK_APP_SECRET"]}" }, format: :json)
  return "Video not found." if !response.success? or !response.parsed_response["source"]
  redirect response.parsed_response["source"]
end

get %r{/facebook/(?<id>\d+)(/(?<username>.+))?} do |id, username|
  @id = id

  @type = %w[videos photos].include?(params[:type]) ? params[:type] : "posts"

  response = HTTParty.get("https://graph.facebook.com/v2.3/#{id}/#{@type}", query: { access_token: "#{ENV["FACEBOOK_APP_ID"]}|#{ENV["FACEBOOK_APP_SECRET"]}" }, format: :json)
  raise FacebookError.new(response) if !response.success?

  @data = response.parsed_response["data"]
  @user = @data[0]["from"]["name"] rescue username
  @title = @user
  @title += "'s #{@type}" if @type != "posts"
  @title += " on Facebook"

  headers "Content-Type" => "application/atom+xml;charset=utf-8"
  erb :facebook_feed
end

get "/instagram" do
  return "Insufficient parameters" if params[:q].empty?

  if /instagram\.com\/p\/(?<post_id>[^\/\?#]+)/ =~ params[:q]
    # https://instagram.com/p/4KaPsKSjni/
    response = HTTParty.get("https://api.instagram.com/v1/media/shortcode/#{post_id}?client_id=#{ENV["INSTAGRAM_CLIENT_ID"]}&client_secret=#{ENV["INSTAGRAM_CLIENT_SECRET"]}", format: :json)
    return response.parsed_response["meta"]["error_message"] if !response.success?
    user = response.parsed_response["data"]["user"]
  elsif /instagram\.com\/(?<name>[^\/\?#]+)/ =~ params[:q]
    # https://instagram.com/infectedmushroom/
  else
    name = params[:q]
  end

  if name
    response = HTTParty.get("https://api.instagram.com/v1/users/search?q=#{name}&client_id=#{ENV["INSTAGRAM_CLIENT_ID"]}&client_secret=#{ENV["INSTAGRAM_CLIENT_SECRET"]}", format: :json)
    raise InstagramError.new(response) if !response.success?
    user = response.parsed_response["data"].find { |user| user["username"] == name }
  end

  if user
    redirect "/instagram/#{user["id"]}/#{user["username"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
  else
    "Can't find a user with that name. Sorry."
  end
end

get "/instagram/download" do
  if /instagram\.com\/p\/(?<post_id>[^\/\?#]+)/ =~ params[:url]
    # https://instagram.com/p/4KaPsKSjni/
    response = HTTParty.get("https://api.instagram.com/v1/media/shortcode/#{post_id}?client_id=#{ENV["INSTAGRAM_CLIENT_ID"]}&client_secret=#{ENV["INSTAGRAM_CLIENT_SECRET"]}", format: :json)
    data = response.parsed_response["data"]
    redirect data["videos"] && data["videos"]["standard_resolution"]["url"] || data["images"]["standard_resolution"]["url"]
  else
    return "Please use a URL directly to a post."
  end
end

get %r{/instagram/(?<user_id>\d+)(/(?<username>.+))?} do |user_id, username|
  @user_id = user_id

  response = HTTParty.get("https://api.instagram.com/v1/users/#{user_id}/media/recent?client_id=#{ENV["INSTAGRAM_CLIENT_ID"]}&client_secret=#{ENV["INSTAGRAM_CLIENT_SECRET"]}", format: :json)
  if response.code == 400
    # user no longer exists or is private, show the error in the feed
    @meta = response.parsed_response["meta"]
    headers "Content-Type" => "application/atom+xml;charset=utf-8"
    return erb :instagram_error
  end
  raise InstagramError.new(response) if !response.success?

  @data = response.parsed_response["data"]
  @user = @data[0]["user"]["username"] rescue username

  type = %w[videos photos].include?(params[:type]) ? params[:type] : "posts"
  if type == "videos"
    @data.select! { |post| post["type"] == "video" }
  elsif type == "photos"
    @data.select! { |post| post["type"] == "image" }
  end

  @title = @user
  @title += "'s #{type}" if type != "posts"
  @title += " on Instagram"

  headers "Content-Type" => "application/atom+xml;charset=utf-8"
  erb :instagram_feed
end

get "/soundcloud" do
  return "Insufficient parameters" if params[:q].empty?

  if /soundcloud\.com\/(?<username>[^\/\?#]+)/ =~ params[:q]
    # https://soundcloud.com/infectedmushroom/01-she-zorement?in=infectedmushroom/sets/converting-vegetarians-ii
  else
    username = params[:q]
  end

  response = HTTParty.get("https://api.soundcloud.com/users?q=#{username}&client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}", format: :json)
  raise SoundcloudError.new(response) if !response.success?
  data = response.parsed_response.first
  return "Can't find a user with that name. Sorry." if !data

  redirect "/soundcloud/#{data["id"]}/#{data["permalink"]}"
end

get "/soundcloud/download" do
  response = HTTParty.get("https://api.soundcloud.com/resolve?url=#{params[:url]}&client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}", follow_redirects: false)
  return "URL does not resolve." if response.code == 404
  raise SoundcloudError.new(response) if response.code != 302
  uri = URI.parse response.parsed_response["location"]
  return "URL does not resolve to a track." if !uri.path.start_with?("/tracks/")
  response = HTTParty.get("#{uri.scheme}://#{uri.host}#{uri.path}/stream?client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}", follow_redirects: false)
  raise SoundcloudError.new(response) if response.code != 302
  redirect response.parsed_response["location"]
end

get %r{/soundcloud/(?<id>\d+)(/(?<username>.+))?} do |id, username|
  @id = id

  response = HTTParty.get("https://api.soundcloud.com/users/#{id}/tracks?client_id=#{ENV["SOUNDCLOUD_CLIENT_ID"]}", format: :json)
  raise SoundcloudError.new(response) if !response.success?

  @data = response.parsed_response
  @username = @data[0]["user"]["permalink"] rescue username
  @user = @data[0]["user"]["username"] rescue username

  headers "Content-Type" => "application/atom+xml;charset=utf-8"
  erb :soundcloud_feed
end

get "/dilbert" do
  @feed = Feedjira::Feed.fetch_and_parse "http://feeds.dilbert.com/DilbertDailyStrip"
  @entries = @feed.entries.map do |entry|
    data = $redis.get "dilbert:#{entry.id}"
    if data
      data = JSON.parse data
    else
      og = OpenGraph.new("http://dilbert.com/strip/#{entry.id}")
      data = {
        "image" => og.images.first,
        "title" => og.title,
        "description" => og.description
      }
      $redis.setex "dilbert:#{entry.id}", 60*60*24*30, data.to_json
    end
    data.merge({
      "id" => entry.id
    })
  end

  headers "Content-Type" => "application/atom+xml;charset=utf-8"
  erb :dilbert
end

get "/favicon.ico" do
  redirect "/img/icon32.png"
end

get %r{^/apple-touch-icon} do
  redirect "/img/icon128.png"
end

if ENV["GOOGLE_VERIFICATION_TOKEN"]
  /(google)?(?<google_token>[0-9a-f]+)(\.html)?/ =~ ENV["GOOGLE_VERIFICATION_TOKEN"]
  get "/google#{google_token}.html" do
    "google-site-verification: google#{google_token}.html"
  end
end

if ENV["LOADERIO_VERIFICATION_TOKEN"]
  /(loaderio-)?(?<loaderio_token>[0-9a-f]+)/ =~ ENV["LOADERIO_VERIFICATION_TOKEN"]
  get Regexp.new("^/loaderio-#{loaderio_token}") do
    headers "Content-Type" => "text/plain"
    "loaderio-#{loaderio_token}"
  end
end


error do |e|
  status 500
  "Sorry, a nasty error occurred: #{e}"
end

error YoutubeError do |e|
  status 503
  "There was a problem talking to YouTube."
end

error FacebookError do |e|
  status 503
  "There was a problem talking to Facebook."
end

error InstagramError do |e|
  status 503
  "There was a problem talking to Instagram."
end

error SoundcloudError do |e|
  status 503
  "There was a problem talking to Soundcloud."
end
