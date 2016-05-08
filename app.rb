require "sinatra"
require "./config/application"
require "active_support/core_ext/string"
require "open-uri"

get "/" do
  erb :index
end

get "/go" do
  return "Insufficient parameters" if params[:q].empty?

  if /^https?:\/\/(www\.|gaming\.)?youtu(\.?be|be\.com)/ =~ params[:q]
    redirect "/youtube?#{params.to_querystring}"
  elsif /^https?:\/\/plus\.google\.com/ =~ params[:q]
    redirect "/googleplus?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?facebook\.com/ =~ params[:q]
    redirect "/facebook?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?instagram\.com/ =~ params[:q]
    redirect "/instagram?#{params.to_querystring}"
  elsif /^https?:\/\/vine\.co/ =~ params[:q]
    redirect "/vine?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?soundcloud\.com/ =~ params[:q]
    redirect "/soundcloud?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?ustream\.tv/ =~ params[:q]
    redirect "/ustream?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?dailymotion\.com/ =~ params[:q]
    redirect "/dailymotion?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?vimeo\.com/ =~ params[:q]
    redirect "/vimeo?#{params.to_querystring}"
  elsif /^https?:\/\/([a-zA-Z0-9]+\.)?imgur\.com/ =~ params[:q]
    redirect "/imgur?#{params.to_querystring}"
  elsif /^https?:\/\/(www\.)?svtplay\.se/ =~ params[:q]
    redirect "/svtplay?#{params.to_querystring}"
  elsif /^https?:\/\/twitter\.com\/(?<user>[^\/?#]+)/ =~ params[:q]
    redirect "https://stefansundin.com/@#{user}"
  else
    "Unknown service"
  end
end

get "/youtube" do
  return "Insufficient parameters" if params[:q].empty?

  if /youtube\.com\/channel\/(?<channel_id>UC[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/channel/UC4a-Gbdw7vOaccHmFo40b9g/videos
  elsif /youtube\.com\/user\/(?<user>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/user/khanacademy/videos
  elsif /youtube\.com\/c\/(?<channel_title>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/c/khanacademy/videos
    # note that channel_title != username, e.g. https://www.youtube.com/c/kawaiiguy and https://www.youtube.com/user/kawaiiguy are two different channels
  elsif /youtube\.com\/.*[?&]v=(?<video_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/watch?v=vVXbgbMp0oY&t=5s
  elsif /youtube\.com\/.*[?&]list=(?<playlist_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/playlist?list=PL0QrZvg7QIgpoLdNFnEePRrU-YJfr9Be7
  elsif /youtube\.com\/(?<user>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/khanacademy
  elsif /youtu\.be\/(?<video_id>[^?#]+)/ =~ params[:q]
    # https://youtu.be/vVXbgbMp0oY?t=1s
  elsif /(?<channel_id>UC[^\/?#]+)/ =~ params[:q]
    # it's a channel id
  else
    # it's probably a channel name
    user = params[:q]
  end

  if user
    response = GoogleParty.get("/youtube/v3/channels", query: { part: "id", forUsername: user })
    raise GoogleError.new(response) if !response.success?
    if response.parsed_response["items"].length > 0
      channel_id = response.parsed_response["items"][0]["id"]
    end
  end

  if channel_title
    response = GoogleParty.get("/youtube/v3/search", query: { part: "id", q: channel_title })
    raise GoogleError.new(response) if !response.success?
    if response.parsed_response["items"].length > 0
      channel_id = response.parsed_response["items"][0]["id"]["channelId"]
    end
  end

  if video_id
    response = GoogleParty.get("/youtube/v3/videos", query: { part: "snippet", id: video_id })
    raise GoogleError.new(response) if !response.success?
    if response.parsed_response["items"].length > 0
      channel_id = response.parsed_response["items"][0]["snippet"]["channelId"]
    end
  end

  if channel_id
    if params[:type]
      # it's no longer possible to get usernames using the API
      og = OpenGraph.new("https://www.youtube.com/channel/#{channel_id}")
      username = og.url.split("/")[-1]
      username = og.title if username == channel_id
      url = "/youtube/#{channel_id}/#{username}?eventType=live,upcoming"
      url += "&tz=#{params[:tz]}" if params[:tz]
      redirect url
    else
      redirect "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel_id}"
    end
  elsif playlist_id
    redirect "https://www.youtube.com/feeds/videos.xml?playlist_id=#{playlist_id}"
  else
    "Could not find the channel. Sorry."
  end
end

get "/youtube/:channel_id/:username" do
  @channel_id = params[:channel_id]
  @username = params[:username]
  @tz = params[:tz]

  query = { part: "snippet", type: "video", order: "date", channelId: params[:channel_id], maxResults: 50 }
  query[:q] = params[:q] if params[:q]

  if params[:eventType]
    @data = params[:eventType].split(",").map do |eventType|
      query[:eventType] = eventType
      response = GoogleParty.get("/youtube/v3/search", query: query)
      response.parsed_response["items"]
    end.flatten.uniq { |v| v["id"]["videoId"] }.sort_by { |v| v["snippet"]["publishedAt"] }.reverse
  else
    response = GoogleParty.get("/youtube/v3/search", query: query)
    @data = response.parsed_response["items"]
  end

  ids = @data.select { |v| %w[upcoming live].include?(v["snippet"]["liveBroadcastContent"]) }.map { |v| v["id"]["videoId"] }
  if ids.any?
    request = GoogleParty.get("/youtube/v3/videos", query: { part: "liveStreamingDetails", id: ids.join(",") })
    if request.success?
      request.parsed_response["items"].each do |data|
        i = @data.find_index { |v| v["id"]["videoId"] == data["id"] }
        @data[i]["liveStreamingDetails"] = data["liveStreamingDetails"]
      end
    end
  end

  content_type :atom
  erb :youtube_feed
end

get "/googleplus" do
  return "Insufficient parameters" if params[:q].empty?
  params[:q] = params[:q].gsub(" ", "+") # spaces in urls is a mess

  if /plus\.google\.com\/(u\/\d+\/)?(?<user>\+[a-zA-Z0-9]+)/ =~ params[:q]
    # https://plus.google.com/+TIME
  elsif /plus\.google\.com\/(u\/\d+\/)?(?<user>\d+)/ =~ params[:q]
    # https://plus.google.com/112161921284629501085
  else
    # it's probably a user name
    user = params[:q]
    user = "+#{user}" if user[0] != "+" and !user.numeric?
  end

  response = GoogleParty.get("/plus/v1/people/#{CGI.escape(user)}")
  return "Can't find a page with that name. Sorry." if response.code == 404
  raise GoogleError.new(response) if !response.success?
  data = response.parsed_response
  user_id = data["id"]
  if /\/\+(?<user>[a-zA-Z0-9]+)$/ =~ data["url"]
    username = user
  else
    username = data["displayName"]
  end

  redirect "/googleplus/#{user_id}/#{username}"
end

get %r{/googleplus/(?<id>\d+)(/(?<username>.+))?} do |id, username|
  @id = id

  response = GoogleParty.get("/plus/v1/people/#{id}/activities/public")
  raise GoogleError.new(response) if !response.success?
  @data = response.parsed_response

  @user = if @data["items"][0]
    @data["items"][0]["actor"]["displayName"]
  else
    username
  end

  content_type :atom
  erb :googleplus_feed
end

get "/vimeo" do
  return "Insufficient parameters" if params[:q].empty?

  if /vimeo\.com\/user(?<user_id>\d+)/ =~ params[:q]
    # https://vimeo.com/user7103699
  elsif /vimeo\.com\/(?<video_id>\d+)/ =~ params[:q]
    # https://vimeo.com/155672086
    response = VimeoParty.get("/videos/#{video_id}")
    raise VimeoError.new(response) if !response.success?
    user_id = response.parsed_response["user"]["uri"].gsub("/users/","").to_i
  elsif /vimeo\.com\/(?<user>[^\/]+)/ =~ params[:q] or user = params[:q]
    # it's probably a channel name
    response = VimeoParty.get("/users", query: { query: user })
    raise VimeoError.new(response) if !response.success?
    if response.parsed_response["data"].length > 0
      user_id = response.parsed_response["data"][0]["uri"].gsub("/users/","").to_i
    end
  end

  if user_id
    redirect "https://vimeo.com/user#{user_id}/videos/rss"
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
  elsif /facebook\.com\/(?<id>[^\/?#]+)/ =~ params[:q]
    # https://www.facebook.com/celldweller/info?tab=overview
  else
    id = params[:q]
  end

  response = FacebookParty.get("/", query: { id: id, metadata: "1" })
  return "Can't find a page with that name. Sorry." if response.code == 404
  raise FacebookError.new(response) if !response.success?
  data = response.parsed_response
  if data["metadata"]["fields"].any? { |field| field["name"] == "from" }
    # this is needed if the url is for e.g. a photo and not the main page
    response = FacebookParty.get("/", query: { id: id, fields: "from", metadata: "1" })
    raise FacebookError.new(response) if !response.success?
    response = FacebookParty.get("/", query: { id: response.parsed_response["from"]["id"], metadata: "1" })
    raise FacebookError.new(response) if !response.success?
    data = response.parsed_response
  end
  if data["metadata"]["fields"].any? { |field| field["name"] == "username" }
    response = FacebookParty.get("/", query: { id: id, fields: "username", metadata: "1" })
    raise FacebookError.new(response) if !response.success?
    data = response.parsed_response
  end

  return "Please use a link directly to the Facebook page." if !data["id"].numeric?
  redirect "/facebook/#{data["id"]}/#{data["username"] || data["name"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
end

get "/facebook/download" do
  if /\/(?<id>\d+)/ =~ params[:url]
    # https://www.facebook.com/infectedmushroom/videos/10153430677732261/
    # https://www.facebook.com/infectedmushroom/videos/vb.8811047260/10153371214897261/?type=2&theater
  else
    id = params[:url]
  end

  response = FacebookParty.get("/", query: { id: id, fields: "source,created_time,title,description" })
  data = response.parsed_response

  if env["HTTP_ACCEPT"] == "application/json"
    content_type :json
    status response.code
    return response.body
  end

  return "Video not found." if !response.success? or !data["source"]
  redirect data["source"]
end

get %r{/facebook/(?<id>\d+)(/(?<username>.+))?} do |id, username|
  @id = id

  @type = %w[videos photos].pick(params[:type]) || "posts"
  fields = {
    "posts"  => "updated_time,from,type,story,name,message,description,link,source,picture",
    "videos" => "updated_time,from,title,description,embeddable,embed_html",
    "photos" => "updated_time,from,message,description,name,link,source",
  }[@type]

  response = FacebookParty.get("/#{id}/#{@type}", query: { fields: fields })
  raise FacebookError.new(response) if !response.success?

  @data = response.parsed_response["data"]
  @user = @data[0]["from"]["name"] rescue username
  @title = @user
  @title += "'s #{@type}" if @type != "posts"
  @title += " on Facebook"

  content_type :atom
  erb :facebook_feed
end

get "/instagram" do
  return "Insufficient parameters" if params[:q].empty?

  if /instagram\.com\/p\/(?<post_id>[^\/?#]+)/ =~ params[:q]
    # https://instagram.com/p/4KaPsKSjni/
    response = InstagramParty.get("/media/shortcode/#{post_id}")
    return response.parsed_response["meta"]["error_message"] if !response.success?
    user = response.parsed_response["data"]["user"]
  elsif /instagram\.com\/(?<name>[^\/?#]+)/ =~ params[:q]
    # https://instagram.com/infectedmushroom/
  else
    name = params[:q]
  end

  if name
    response = InstagramParty.get("/users/search", query: { q: name })
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
  if /instagram\.com\/p\/(?<post_id>[^\/?#]+)/ =~ params[:url]
    # https://instagram.com/p/4KaPsKSjni/
    response = InstagramParty.get("/media/shortcode/#{post_id}")
    data = response.parsed_response["data"]
    redirect data["videos"] && data["videos"]["standard_resolution"]["url"] || data["images"]["standard_resolution"]["url"]
  else
    return "Please use a URL directly to a post."
  end
end

get %r{/instagram/(?<user_id>\d+)(/(?<username>.+))?} do |user_id, username|
  @user_id = user_id

  response = InstagramParty.get("/users/#{user_id}/media/recent")
  if response.code == 400
    # user no longer exists or is private, show the error in the feed
    @meta = response.parsed_response["meta"]
    content_type :atom
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

  content_type :atom
  erb :instagram_feed
end

get "/vine" do
  return "Insufficient parameters" if params[:q].empty?

  if /vine\.co\/popular-now/ =~ params[:q]
    redirect "/vine/popular-now"
  elsif /vine\.co\/u\/(?<user_id>[^\/?#]+)/ =~ params[:q]
    # https://vine.co/u/916394797705605120
  elsif /vine\.co\/v\/(?<post_id>[^\/?#]+)/ =~ params[:q]
    # https://vine.co/v/iJgLDBPKO3I
  elsif /vine\.co\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://vine.co/nasa
  else
    username = params[:q]
  end

  if user_id
    response = VineParty.get("/users/profiles/#{user_id}")
    raise VineError.new(response) if !response.success?
    username = response.parsed_response["data"]["username"]
  elsif post_id
    response = VineParty.get("/timelines/posts/s/#{post_id}")
    return "That post does not exist." if response.code == 404
    raise VineError.new(response) if !response.success?
    data = response.parsed_response["data"]["records"][0]
    user_id = data["userId"]
    username = data["vanityUrls"][0] || data["username"]
  elsif username
    response = VineParty.get("/users/profiles/vanity/#{CGI.escape(username)}")
    return "That username does not exist." if response.code == 404
    raise VineError.new(response) if !response.success?
    data = response.parsed_response["data"]
    user_id = data["userId"]
    username = data["vanityUrls"][0] || data["username"]
  end

  redirect "/vine/#{user_id}/#{username}"
end

get %r{/vine/(?<id>\d+)(/(?<username>.+))?} do |id, username|
  @id = id
  @username = username

  response = VineParty.get("/timelines/users/#{id}")
  raise VineError.new(response) if !response.success?
  @data = response.parsed_response["data"]["records"]

  @user = if !@data.first
    @username
  elsif @data.first["repost"]
    @data.first["repost"]["user"]["username"]
  else
    @data.first["username"]
  end

  content_type :atom
  erb :vine_feed
end

get "/vine/popular-now" do
  @id = "popular-now"
  @username = "popular-now"
  @user = "Popular Now"

  response = VineParty.get("/timelines/popular")
  raise VineError.new(response) if !response.success?
  @data = response.parsed_response["data"]["records"]

  content_type :atom
  erb :vine_feed
end

get "/vine/download" do
  if /vine\.co\/v\/(?<post_id>[a-zA-Z0-9]+)/ =~ params[:url]
    # https://vine.co/v/iJgLDBPKO3I
  else
    return "Please use a link directly to a post."
  end

  response = VineParty.get("/timelines/posts/s/#{post_id}")
  return "Post does not exist." if response.code == 404
  raise VineError.new(response) if !response.success?
  redirect response.parsed_response["data"]["records"][0]["videoUrls"][0]["videoUrl"]
end

get "/soundcloud" do
  return "Insufficient parameters" if params[:q].empty?

  if /soundcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://soundcloud.com/infectedmushroom/01-she-zorement?in=infectedmushroom/sets/converting-vegetarians-ii
  else
    username = params[:q]
  end

  response = SoundcloudParty.get("/users", query: { q: username })
  raise SoundcloudError.new(response) if !response.success?
  data = response.parsed_response.first
  return "Can't find a user with that name. Sorry." if !data

  redirect "/soundcloud/#{data["id"]}/#{data["permalink"]}"
end

get "/soundcloud/download" do
  response = SoundcloudParty.get("/resolve", query: { url: params[:url] }, follow_redirects: false)
  return "URL does not resolve." if response.code == 404
  raise SoundcloudError.new(response) if response.code != 302
  uri = URI.parse response.parsed_response["location"]
  return "URL does not resolve to a track." if !uri.path.start_with?("/tracks/")
  response = SoundcloudParty.get("#{uri.path}/stream", follow_redirects: false)
  raise SoundcloudError.new(response) if response.code != 302
  redirect response.parsed_response["location"]
end

get %r{/soundcloud/(?<id>\d+)(/(?<username>.+))?} do |id, username|
  @id = id

  response = SoundcloudParty.get("/users/#{id}/tracks")
  raise SoundcloudError.new(response) if !response.success?

  @data = response.parsed_response
  @username = @data[0]["user"]["permalink"] rescue username
  @user = @data[0]["user"]["username"] rescue username

  content_type :atom
  erb :soundcloud_feed
end

get "/ustream" do
  return "Insufficient parameters" if params[:q].empty?

  url = if /^https?:\/\/(www\.)?ustream\.tv\// =~ params[:q]
    # http://www.ustream.tv/recorded/74562214
    # http://www.ustream.tv/githubuniverse
    params[:q]
  else
    "http://www.ustream.tv/#{params[:q]}"
  end
  begin
    doc = Nokogiri::HTML(open(url))
    channel_id = doc.at("meta[name='ustream:channel_id']")["content"].to_i
  rescue
    return "Could not find the channel."
  end

  response = UstreamParty.get("/channels/#{channel_id}.json")
  raise UstreamError.new(response) if !response.success?
  channel_title = response.parsed_response["channel"]["title"]

  redirect "/ustream/#{channel_id}/#{channel_title}"
end

get %r{/ustream/(?<id>\d+)(/(?<title>.+))?} do |id, title|
  @id = id
  @user = title

  response = UstreamParty.get("/channels/#{id}/videos.json")
  raise UstreamError.new(response) if !response.success?
  @data = response.parsed_response["videos"]

  content_type :atom
  erb :ustream_feed
end

get "/ustream/download" do
  if /ustream\.tv\/recorded\/(?<id>\d+)/ =~ params[:url]
    # http://www.ustream.tv/recorded/74562214
  else
    return "Please use a link directly to a video."
  end

  response = UstreamParty.get("/videos/#{id}.json")
  return "Video does not exist." if response.code == 404
  raise UstreamError.new(response) if !response.success?
  redirect response.parsed_response["video"]["media_urls"]["flv"]
end

get "/dailymotion" do
  return "Insufficient parameters" if params[:q].empty?

  if /dailymotion\.com\/video\/(?<video_id>[a-z0-9]+)/ =~ params[:q]
    # http://www.dailymotion.com/video/x3r4xy2_recut-9-cultural-interchange_fun
  elsif /dailymotion\.com\/playlist\/(?<playlist_id>[a-z0-9]+)/ =~ params[:q]
    # http://www.dailymotion.com/playlist/x4bnhu_GeneralGrin_fair-use-recuts/1
  elsif /dailymotion\.com\/((followers|subscriptions|playlists\/user|user)\/)?(?<user>[^\/?#]+)/ =~ params[:q]
    # http://www.dailymotion.com/followers/GeneralGrin/1
    # http://www.dailymotion.com/subscriptions/GeneralGrin/1
    # http://www.dailymotion.com/playlists/user/GeneralGrin/1
    # http://www.dailymotion.com/user/GeneralGrin/1
    # http://www.dailymotion.com/GeneralGrin
  else
    # it's probably a user name
    user = params[:q]
  end

  if video_id
    response = DailymotionParty.get("/video/#{video_id}")
    raise DailymotionError.new(response) if !response.success?
    user = response.parsed_response["owner"]
  elsif playlist_id
    response = DailymotionParty.get("/playlist/#{playlist_id}")
    raise DailymotionError.new(response) if !response.success?
    user = response.parsed_response["owner"]
  end

  response = DailymotionParty.get("/user/#{CGI.escape(user)}")
  if response.success?
    user_id = response.parsed_response["id"]
    screenname = response.parsed_response["screenname"]
    redirect "/dailymotion/#{user_id}/#{screenname}"
  else
    content_type :text
    "Could not find a user with the name #{user}. Sorry."
  end
end

get %r{/dailymotion/(?<user_id>[a-z0-9]+)(/(?<screenname>.+))?} do |user_id, screenname|
  @user_id = user_id
  @screenname = screenname

  response = DailymotionParty.get("/user/#{user_id}/videos", query: { fields: "id,title,created_time,description,allow_embed,available_formats,duration" })
  raise DailymotionError.new(response) if !response.success?
  @data = response.parsed_response["list"]

  content_type :atom
  erb :dailymotion_feed
end

get "/imgur" do
  return "Insufficient parameters" if params[:q].empty?

  if /imgur\.com\/user\/(?<username>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/user/thebookofgray
  elsif /imgur\.com\/a\/(?<album_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/a/IwyIm
  elsif /imgur\.com\/r\/(?<subreddit>[a-zA-Z0-9_]+)/ =~ params[:q] or /reddit\.com\/r\/(?<subreddit>[a-zA-Z0-9_]+)/ =~ params[:q]
    # https://imgur.com/r/aww
    # https://www.reddit.com/r/aww
    redirect "https://imgur.com/r/#{subreddit}/rss"
  elsif /(?<username>[a-zA-Z0-9]+)\.imgur\.com/ =~ params[:q] and username != "i"
    # https://thebookofgray.imgur.com/
  elsif /imgur\.com\/(gallery\/)?(?<image_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/NdyrgaE
    # https://imgur.com/gallery/NdyrgaE
  else
    # it's probably a username
    username = params[:q]
  end

  if image_id
    response = ImgurParty.get("/gallery/image/#{image_id}")
    response = ImgurParty.get("/image/#{image_id}") if !response.success?
    raise ImgurError.new(response) if !response.success?
    user_id = response.parsed_response["data"]["account_id"]
    username = response.parsed_response["data"]["account_url"]
  elsif album_id
    response = ImgurParty.get("/album/#{album_id}")
    raise ImgurError.new(response) if !response.success?
    user_id = response.parsed_response["data"]["account_id"]
    username = response.parsed_response["data"]["account_url"]
  elsif username
    response = ImgurParty.get("/account/#{CGI.escape(username)}")
    raise ImgurError.new(response) if !response.success?
    user_id = response.parsed_response["data"]["id"]
    username = response.parsed_response["data"]["url"]
  end

  if user_id.nil?
    "This image was probably uploaded anonymously. Sorry."
  else
    redirect "/imgur/#{user_id}/#{username}"
  end
end

get "/imgur/:user_id/:username" do
  @user_id = params[:user_id]
  @username = params[:username]

  # can't use user_id in this request unfortunately
  response = ImgurParty.get("/account/#{@username}/submissions")
  raise ImgurError.new(response) if !response.success?
  @data = response.parsed_response["data"]

  content_type :atom
  erb :imgur_feed
end

get "/svtplay" do
  return "Insufficient parameters" if params[:q].empty?

  if /https?:\/\/(?:www\.)?svtplay\.se\/video\/(?<video_id>.+)/ =~ params[:q]
    # http://www.svtplay.se/video/7181623/veckans-brott/veckans-brott-sasong-12-avsnitt-10
  elsif /https?:\/\/(www\.)?svtplay\.se\/(?<program>[^\/]+)/ =~ params[:q]
    # http://www.svtplay.se/veckans-brott
  else
    # it's probably a program name
    program = params[:q].downcase.gsub(/[:.]/, "").gsub("", "").gsub(" ", "-")
  end

  if video_id
    doc = Nokogiri::HTML(open("http://www.svtplay.se/video/#{video_id}"))
    url = doc.at("link[type='application/atom+xml']")["href"]
  elsif program
    url = "http://www.svtplay.se/#{program}/atom.xml"
  end

  if url
    redirect url
  else
    "Could not find the channel. Sorry."
  end
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

  content_type :atom
  erb :dilbert
end

get "/favicon.ico" do
  redirect "/img/icon32.png"
end

get %r{^/apple-touch-icon} do
  redirect "/img/icon128.png"
end

get "/opensearch.xml" do
  content_type :opensearch
  erb :opensearch
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
    content_type :text
    "loaderio-#{loaderio_token}"
  end
end


error do |e|
  status 500
  "Sorry, a nasty error occurred: #{e}"
end
