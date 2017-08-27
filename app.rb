require "sinatra"
require "./config/application"
require "active_support/core_ext/string"
require "open-uri"

before do
  content_type :text
end

get "/" do
  SecureHeaders.use_secure_headers_override(request, :index)
  erb :index
end

get "/live" do
  content_type :html
  SecureHeaders.use_secure_headers_override(request, :live)
  send_file File.join(settings.public_folder, 'live.html')
end

get "/go" do
  return "Insufficient parameters" if params[:q].empty?

  if /^https?:\/\/(?:mobile\.)?twitter\.com\// =~ params[:q]
    redirect "/twitter?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.|gaming\.)?youtu(?:\.be|be\.com)/ =~ params[:q]
    redirect "/youtube?#{params.to_querystring}"
  elsif /^https?:\/\/plus\.google\.com/ =~ params[:q]
    redirect "/googleplus?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?facebook\.com/ =~ params[:q]
    redirect "/facebook?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?instagram\.com/ =~ params[:q]
    redirect "/instagram?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?periscope\.tv/ =~ params[:q]
    redirect "/periscope?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?soundcloud\.com/ =~ params[:q]
    redirect "/soundcloud?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?mixcloud\.com/ =~ params[:q]
    redirect "/mixcloud?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?twitch\.tv/ =~ params[:q]
    redirect "/twitch?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?speedrun\.com/ =~ params[:q]
    redirect "/speedrun?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?ustream\.tv/ =~ params[:q]
    redirect "/ustream?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?dailymotion\.com/ =~ params[:q]
    redirect "/dailymotion?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?vimeo\.com/ =~ params[:q]
    redirect "/vimeo?#{params.to_querystring}"
  elsif /^https?:\/\/(?:[a-zA-Z0-9]+\.)?imgur\.com/ =~ params[:q]
    redirect "/imgur?#{params.to_querystring}"
  elsif /^https?:\/\/(?<user>[a-zA-Z0-9\-]+)\.deviantart\.com/ =~ params[:q]
    redirect "https://backend.deviantart.com/rss.xml?type=deviation&q=by%3A#{user}+sort%3Atime"
  elsif /^https?:\/\/(?:www\.)?svtplay\.se/ =~ params[:q]
    redirect "/svtplay?#{params.to_querystring}"
  else
    "Unknown service"
  end
end

get "/twitter" do
  return "Insufficient parameters" if params[:q].empty?

  if params[:q]["twitter.com/i/"] or params[:q]["twitter.com/who_to_follow/"]
    return "Unsupported url. Sorry."
  elsif params[:q]["twitter.com/hashtag/"]
    return "This app does not support hashtags. Sorry."
  elsif /twitter\.com\/(?:#!\/|@)?(?<user>[^\/?#]+)/ =~ params[:q] or /@(?<user>[^\/?#]+)/ =~ params[:q]
    # https://twitter.com/#!/infected
    # https://twitter.com/infected
    # @username
  else
    # it's probably a username
    user = params[:q]
  end

  response = TwitterParty.get("/users/lookup.json", query: { screen_name: user })
  return "Can't find a user with that name. Sorry." if response.code == 404
  raise TwitterError.new(response) if !response.success?

  user_id = response.parsed_response[0]["id_str"]
  screen_name = response.parsed_response[0]["screen_name"]
  redirect "/twitter/#{user_id}/#{screen_name}#{"?#{params[:type]}" if !params[:type].empty?}"
end

get %r{/twitter/(?<id>\d+)/(?<username>.+)} do |id, username|
  @user_id = id

  response = TwitterParty.get("/statuses/user_timeline.json", query: {
    user_id: id,
    count: 100,
    include_rts: params[:include_rts] || "1",
    exclude_replies: params[:exclude_replies] || "0",
    tweet_mode: "extended"
  })
  status response.code
  return response.body if response.code == 401
  return "This user id no longer exists. The user was likely deleted or recreated. Try resubscribing." if response.code == 404
  raise TwitterError.new(response) if !response.success?

  @data = response.parsed_response
  @username = @data[0]["user"]["screen_name"] rescue CGI.unescape(username)

  erb :twitter_feed
end

get "/youtube" do
  return "Insufficient parameters" if params[:q].empty?

  if /youtube\.com\/channel\/(?<channel_id>(UC|S)[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/channel/UC4a-Gbdw7vOaccHmFo40b9g/videos
    # https://www.youtube.com/channel/SWu5RTwuNMv6U
  elsif /\b(?<channel_id>(?:UC[^\/?#]{22,}|S[^\/?#]{12,}))/ =~ params[:q]
    # it's a channel id
  elsif /youtube\.com\/user\/(?<user>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/user/khanacademy/videos
  elsif /youtube\.com\/(?<channel_type>c|show)\/(?<channel_title>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/c/khanacademy
    # https://www.youtube.com/show/redvsblue
    # there is no way to resolve these accurately through the API, the best way is to look for the channelId meta tag in the website HTML
    # note that channel_title != username, e.g. https://www.youtube.com/c/kawaiiguy and https://www.youtube.com/user/kawaiiguy are two different channels
    doc = Nokogiri::HTML(open("https://www.youtube.com/#{channel_type}/#{channel_title}"))
    channel_id = doc.at("meta[itemprop='channelId']")["content"]
  elsif /youtube\.com\/.*[?&]v=(?<video_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/watch?v=vVXbgbMp0oY&t=5s
  elsif /youtube\.com\/.*[?&]list=(?<playlist_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/playlist?list=PL0QrZvg7QIgpoLdNFnEePRrU-YJfr9Be7
  elsif /youtube\.com\/(?<user>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/khanacademy
  elsif /youtu\.be\/(?<video_id>[^?#]+)/ =~ params[:q]
    # https://youtu.be/vVXbgbMp0oY?t=1s
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

  query = { part: "id", type: "video", order: "date", channelId: params[:channel_id], maxResults: 50 }
  if params[:q]
    query[:q] = params[:q]
    @title = "\"#{params[:q]}\" from #{@username}"
  else
    @title = "#{@username} on YouTube"
  end

  ids = if params[:eventType]
    params[:eventType].split(",").map do |eventType|
      query[:eventType] = eventType
      response = GoogleParty.get("/youtube/v3/search", query: query)
      raise GoogleError.new(response) if !response.success?
      response.parsed_response["items"]
    end.flatten.uniq { |v| v["id"]["videoId"] }.sort_by { |v| v["snippet"]["publishedAt"] }.reverse
  else
    response = GoogleParty.get("/youtube/v3/search", query: query)
    raise GoogleError.new(response) if !response.success?
    response.parsed_response["items"]
  end.map { |v| v["id"]["videoId"] }

  response = GoogleParty.get("/youtube/v3/videos", query: { part: "snippet,liveStreamingDetails", id: ids.join(",") })
  raise GoogleError.new(response) if !response.success?
  @data = response.parsed_response["items"]

  if params[:q]
    q = params[:q].downcase
    @data.select! { |v| v["snippet"]["title"].downcase[q] }
  end

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
    # it's probably a username
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

get %r{/googleplus/(?<id>\d+)/(?<username>.+)} do |id, username|
  @id = id

  response = GoogleParty.get("/plus/v1/people/#{id}/activities/public")
  raise GoogleError.new(response) if !response.success?
  @data = response.parsed_response

  @user = if @data["items"][0]
    @data["items"][0]["actor"]["displayName"]
  else
    CGI.unescape(username)
  end

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
  elsif /vimeo\.com\/(?:channels\/)?(?<user>[^\/]+)/ =~ params[:q] or user = params[:q]
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
  params[:q].gsub!("facebookcorewwwi.onion", "facebook.com") if params[:q]["facebookcorewwwi.onion"]

  if /facebook\.com\/pages\/[^\/]+\/(?<id>\d+)/ =~ params[:q]
    # https://www.facebook.com/pages/Lule%C3%A5-Sweden/106412259396611?fref=ts
  elsif /facebook\.com\/groups\/(?<id>\d+)/ =~ params[:q]
    # https://www.facebook.com/groups/223764997793315
  elsif /facebook\.com\/video\/[^\d]+(?<id>\d+)/ =~ params[:q]
    # https://www.facebook.com/video/embed?video_id=1192228974143110
  elsif /facebook\.com\/[^\/]+-(?<id>[\d]+)/ =~ params[:q]
    # https://www.facebook.com/TNG-Recuts-867357396651373/
  elsif /facebook\.com\/(?:pg\/)?(?<id>[^\/?#]+)/ =~ params[:q]
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
    id = response.parsed_response["from"]["id"]
    response = FacebookParty.get("/", query: { id: id, metadata: "1" })
    raise FacebookError.new(response) if !response.success?
    data = response.parsed_response
  end
  if data["metadata"]["fields"].any? { |field| field["name"] == "username" }
    response = FacebookParty.get("/", query: { id: id, fields: "username,name" })
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
  elsif /\d+_(?<id>\d+)/ =~ params[:url]
  elsif /v=(?<id>\d+)/ =~ params[:url]
  elsif /(?<id>\d+)/ =~ params[:url]
  else
    id = params[:url]
  end

  response = FacebookParty.get("/", query: { id: id, metadata: "1" })
  if response.success?
    type = response.parsed_response["metadata"]["type"]
    if type == "video"
      response = FacebookParty.get("/", query: { id: id, fields: "source,created_time,title,description,live_status,from" })
      status response.code
      data = response.parsed_response
      fn = "#{data["created_time"].to_date} - #{data["title"] || data["description"] || data["from"]["name"]}#{" (live)" if data["live_status"]}.mp4".to_filename
      url = if data["live_status"] == "LIVE"
        "https://www.facebook.com/video/playback/playlist.m3u8?v=#{data["id"]}"
      else
        data["source"]
      end

      if env["HTTP_ACCEPT"] == "application/json"
        content_type :json
        return {
          url: url,
          filename: fn,
          live: (data["live_status"] == "LIVE")
        }.to_json
      end

      if data["live_status"] == "LIVE"
        "ffmpeg -i \"#{url}\" \"#{fn}\""
      else
        redirect url
      end
    elsif type == "photo"
      response = FacebookParty.get("/", query: { id: id, fields: "images" })
      data = response.parsed_response
      image = data["images"][0]
      redirect image["source"]
    else
      return "Unknown type (#{type})."
    end
  else
    if response.parsed_response["error"]["code"] == 100
      # The video/photo is probably uploaded by a regular Facebook user (i.e. not uploaded to a page), which we can't get info from via the API.
      # Video example: https://www.facebook.com/ofer.dikovsky/videos/10154633221533413/
      # Photo example: 1401133169914577
      response = HTTP.get("https://www.facebook.com/#{id}")
      if response.success?
        if /<title[^>]*>(?<title>[^<]+)<\/title>/ =~ response.body and /data-utime="(?<utime>\d+)"/ =~ response.body
          title = title.gsub!(" | Facebook", "")
          created_time = Time.at(utime.to_i)
          fn = "#{created_time.to_date} - #{title}.mp4".to_filename.force_encoding("UTF-8")
        end
        if /hd_src_no_ratelimit:"(?<url>[^"]+)"/ =~ response.body
        elsif /https:\/\/[^"]+_#{id}_[^"]+\.jpg[^"]+/o =~ response.body
          # This is not the best quality of the picture, but it will have to do
          url = CGI.unescapeHTML($&)
        end
        if url
          if env["HTTP_ACCEPT"] == "application/json"
            content_type :json
            return {
              url: url,
              filename: fn
            }.to_json
          end
          redirect url
        else
          return "Video/photo not found."
        end
      else
        return "https://www.facebook.com/#{id} returned #{response.code}"
      end
    else
      status response.code
      return response.parsed_response.to_json
    end
  end
end

get %r{/facebook/(?<id>\d+)/(?<username>.+)} do |id, username|
  @id = id

  @type = @edge = %w[videos photos live].pick(params[:type]) || "posts"
  @edge = "videos" if @type == "live"
  fields = {
    "posts"  => "updated_time,from,parent_id,type,story,name,message,description,link,source,picture,full_picture,properties",
    "videos" => "updated_time,from,title,description,embed_html,length,live_status",
    "photos" => "updated_time,from,message,description,name,link,source",
  }[@edge]

  response = FacebookParty.get("/#{id}/#{@edge}", query: { fields: fields, since: Time.now.to_i-365*24*60*60 }) # date -v -1w +%s
  raise FacebookError.new(response) if !response.success?

  @data = response.parsed_response["data"]
  if @edge == "posts"
    # copy down video length from properties array
    @data.each do |post|
      if post["properties"]
        post["properties"].each do |prop|
          if prop["name"] == "Length" and /^(?<m>\d+):(?<s>\d+)$/ =~ prop["text"]
            post["length"] = 60*m.to_i + s.to_i
          end
        end
      end
    end
  elsif @type == "live"
    @data.select! { |post| post["live_status"] }
  end

  # Remove live videos from most feeds
  if @type != "live"
    @data.select! { |post| post["live_status"] != "LIVE" }
  end

  @user = @data[0]["from"]["name"] rescue CGI.unescape(username)
  @title = @user
  if @type == "live"
    @title += "'s live videos"
  elsif @type != "posts"
    @title += "'s #{@type}"
  end
  @title += " on Facebook"

  erb :facebook_feed
end

get "/instagram" do
  return "Insufficient parameters" if params[:q].empty?

  if /instagram\.com\/p\/(?<post_id>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/p/4KaPsKSjni/
    response = InstagramParty.get("/p/#{post_id}/")
    return InstagramError.new(response) if !response.success?
    user = response.parsed_response["graphql"]["shortcode_media"]["owner"]
  elsif params[:q]["instagram.com/explore/"]
    return "This app does not support hashtags. Sorry."
  elsif /instagram\.com\/(?<name>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/infectedmushroom/
  else
    name = params[:q]
  end

  if name
    response = InstagramParty.get("/#{CGI.escape(name)}/")
    if response.success?
      user = response.parsed_response["user"]
    else
      # https://www.instagram.com/web/search/topsearch/?query=infected
      response = InstagramParty.get("/web/search/topsearch/", query: { query: name })
      raise InstagramError.new(response) if !response.success?
      user = response.parsed_response["users"][0]["user"]
    end
  end

  if user
    redirect "/instagram/#{user["id"] || user["pk"]}/#{user["username"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
  else
    "Can't find a user with that name. Sorry."
  end
end

get "/instagram/download" do
  if /instagram\.com\/p\/(?<post_id>[^\/?#]+)/ =~ params[:url]
    # https://www.instagram.com/p/4KaPsKSjni/
  else
    post_id = params[:url]
  end

  response = InstagramParty.get("/p/#{post_id}/")
  return "Please use a URL directly to a post." if !response.success?
  data = response.parsed_response["graphql"]["shortcode_media"]
  url = data["video_url"] || data["display_url"]

  if env["HTTP_ACCEPT"] == "application/json"
    content_type :json
    status response.code
    created_at = Time.at(data["taken_at_timestamp"])
    caption = data["edge_media_to_caption"]["edges"][0]["node"]["text"] rescue post_id
    return {
      url: url,
      filename: "#{created_at.to_date} - #{data["owner"]["username"]} - #{caption}#{url.url_ext}".to_filename
    }.to_json
  end

  redirect url
end

get %r{/instagram/(?<user_id>\d+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id

  response = InstagramParty.get("/#{username}/")
  return "Instagram username does not exist. If the user changed their username, go here to find the new username: https://www.instagram.com/graphql/query/?query_id=17880160963012870&id=#{@user_id}&first=1" if response.code == 404
  raise InstagramError.new(response) if !response.success?

  @data = response.parsed_response["user"]
  @user = @data["username"] rescue CGI.unescape(username)

  type = %w[videos photos].pick(params[:type]) || "posts"
  if type == "videos"
    @data["media"]["nodes"].select! { |post| post["is_video"] }
  elsif type == "photos"
    @data["media"]["nodes"].select! { |post| !post["is_video"] }
  end

  @title = @user
  @title += "'s #{type}" if type != "posts"
  @title += " on Instagram"

  erb :instagram_feed
end

get "/periscope" do
  return "Insufficient parameters" if params[:q].empty?

  if /periscope\.tv\/w\/(?<broadcast_id>[^\/?#]+)/ =~ params[:q]
    # https://www.periscope.tv/w/1gqxvBmMZdexB
  elsif /periscope\.tv\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.periscope.tv/jimmy_dore
  else
    username = params[:q]
  end

  url = if broadcast_id
    "https://www.periscope.tv/w/#{broadcast_id}"
  else
    "https://www.periscope.tv/#{CGI.escape(username)}"
  end
  response = HTTP.get(url)
  return "That username does not exist." if response.code == 404
  return "That broadcast has expired." if response.code == 410
  raise PeriscopeError.new(response) if !response.success?
  doc = Nokogiri::HTML(response.body)
  data = doc.at("div#page-container")["data-store"]
  json = JSON.parse(data)
  username, user_id = json["UserCache"]["usernames"].first

  redirect "/periscope/#{user_id}/#{username}"
end

get %r{/periscope/(?<id>[^/]+)/(?<username>.+)} do |id, username|
  @id = id
  @username = CGI.unescape(username)

  response = PeriscopeParty.get_broadcasts(id)
  raise PeriscopeError.new(response) if !response.success?
  @data = response.parsed_response["broadcasts"]
  @user = if @data.first
    @data.first["user_display_name"]
  else
    @username
  end

  erb :periscope_feed
end

get "/soundcloud" do
  return "Insufficient parameters" if params[:q].empty?

  if /soundcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://soundcloud.com/infectedmushroom/01-she-zorement?in=infectedmushroom/sets/converting-vegetarians-ii
  else
    username = params[:q]
  end

  response = SoundcloudParty.get("/resolve", query: { url: "https://soundcloud.com/#{username}" })
  if response.code == 302
    uri = Addressable::URI.parse(response.parsed_response["location"])
    return "URL does not resolve to a user." if !uri.path.start_with?("/users/")
    id = uri.path[/\d+/]
  elsif response.code == 404 && username.numeric?
    response = SoundcloudParty.get("/users/#{username}")
    return "Can't find a user with that id. Sorry." if response.code == 404
    raise SoundcloudError.new(response) if !response.success?
    id = response.parsed_response["id"]
  elsif response.code == 404
    return "Can't find a user with that name. Sorry."
  else
    raise SoundcloudError.new(response)
  end

  response = SoundcloudParty.get("/users/#{id}")
  raise SoundcloudError.new(response) if !response.success?
  data = response.parsed_response

  redirect "/soundcloud/#{data["id"]}/#{data["permalink"]}"
end

get "/soundcloud/download" do
  url = params[:url]
  url = "https://#{url}" if !url.start_with?("http:", "https:")
  response = SoundcloudParty.get("/resolve", query: { url: url })
  return "URL does not resolve." if response.code == 404
  raise SoundcloudError.new(response) if response.code != 302
  uri = Addressable::URI.parse(response.parsed_response["location"])
  return "URL does not resolve to a track." if !uri.path.start_with?("/tracks/")
  response = SoundcloudParty.get("#{uri.path}/stream")
  raise SoundcloudError.new(response) if response.code != 302
  media_url = response.parsed_response["location"]

  if env["HTTP_ACCEPT"] == "application/json"
    response = SoundcloudParty.get("#{uri.path}")
    content_type :json
    status response.code
    data = response.parsed_response
    created_at = Time.parse(data["created_at"])
    return {
      url: media_url,
      filename: "#{created_at.to_date} - #{data["title"]}.mp3".to_filename
    }.to_json
  end

  redirect media_url
end

get %r{/soundcloud/(?<id>\d+)/(?<username>.+)} do |id, username|
  @id = id

  response = SoundcloudParty.get("/users/#{id}/tracks")
  raise SoundcloudError.new(response) if !response.success?

  @data = response.parsed_response
  @username = @data[0]["user"]["permalink"] rescue CGI.unescape(username)
  @user = @data[0]["user"]["username"] rescue CGI.unescape(username)

  erb :soundcloud_feed
end

get "/mixcloud" do
  return "Insufficient parameters" if params[:q].empty?

  if /mixcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.mixcloud.com/infected-live/infected-mushroom-liveedc-las-vegas-21-5-2014/
  else
    username = params[:q]
  end

  response = MixcloudParty.get("/#{username}/")
  return "Can't find a user with that name. Sorry." if response.code == 404
  raise MixcloudError.new(response) if !response.success?
  data = response.parsed_response

  redirect "/mixcloud/#{data["username"]}/#{data["name"]}"
end

get %r{/mixcloud/(?<username>[^/]+)/(?<user>.+)} do |username, user|
  response = MixcloudParty.get("/#{username}/cloudcasts/")
  raise MixcloudError.new(response) if !response.success?

  @data = response.parsed_response["data"]
  @username = @data[0]["user"]["username"] rescue CGI.unescape(username)
  @user = @data[0]["user"]["name"] rescue CGI.unescape(user)

  erb :mixcloud_feed
end

get "/twitch" do
  return "Insufficient parameters" if params[:q].empty?

  if /twitch\.tv\/videos\/(?<vod_id>\d+)/ =~ params[:q]
    # https://www.twitch.tv/videos/25133028
  elsif /twitch\.tv\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.twitch.tv/majinphil
  else
    username = params[:q]
  end

  if vod_id
    response = TwitchParty.get("/kraken/videos/v#{vod_id}")
    return "Video does not exist." if response.code == 404
    raise TwitchError.new(response) if !response.success?
    data = response.parsed_response
    username = data["channel"]["name"]
  end

  response = TwitchParty.get("/kraken/channels/#{username}")
  return "Can't find a user with that name. Sorry." if response.code == 404
  raise TwitchError.new(response) if !response.success?
  data = response.parsed_response

  redirect "/twitch/#{data["_id"]}/#{data["name"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
end

get "/twitch/download" do
  if /clips\.twitch\.tv\/(?:embed\?clip=)?(?<clip_slug>[^?&#]+)/ =~ params[:url]
    # https://clips.twitch.tv/majinphil/UnusualClamRaccAttack
    # https://clips.twitch.tv/embed?clip=majinphil/UnusualClamRaccAttack&autoplay=false
  elsif /twitch\.tv\/videos\/(?<vod_id>\d+)/ =~ params[:url] or /twitch\.tv\/(?:[^\/]+)\/v\/(?<vod_id>\d+)/ =~ params[:url] or /(^|v)(?<vod_id>\d+)/ =~ params[:url]
    # https://www.twitch.tv/videos/25133028
    # https://www.twitch.tv/gamesdonequick/v/34377308?t=53m40s
    # https://player.twitch.tv/?video=v103620362
  elsif /twitch\.tv\/(?<channel_name>[^\/?#]+)/ =~ params[:url]
    # https://www.twitch.tv/trevperson
  else
    channel_name = params[:url]
  end

  if clip_slug
    response = HTTP.get("https://clips.twitch.tv/embed?clip=#{clip_slug}")
    return "Clip does not seem to exist." if response.code == 404
    raise TwitchError.new(response) if !response.success?
    url = response.body[/https:\/\/clips-media-assets\.twitch\.tv\/.+?\.mp4/]
    return "Can't find clip." if url.nil?
    redirect url
    return
  elsif vod_id
    response = TwitchParty.get("/kraken/videos/v#{vod_id}")
    return "Video does not exist." if response.code == 404
    raise TwitchError.new(response) if !response.success?
    data = response.parsed_response

    response = TwitchParty.get("/api/vods/#{vod_id}/access_token")
    raise TwitchError.new(response) if !response.success?
    vod_data = response.parsed_response

    url = "http://usher.twitch.tv/vod/#{vod_id}?nauthsig=#{vod_data["sig"]}&nauth=#{CGI.escape(vod_data["token"])}"
    fn = "#{data["created_at"].to_date} - #{data["channel"]["display_name"]} - #{data["title"]}.mp4".to_filename
  elsif channel_name
    response = TwitchParty.get("/api/channels/#{channel_name}/access_token")
    return "Channel does not seem to exist." if response.code == 404
    raise TwitchError.new(response) if !response.success?

    data = response.parsed_response
    token_data = JSON.parse(data["token"])

    url = "http://usher.ttvnw.net/api/channel/hls/#{token_data["channel"]}.m3u8?token=#{CGI.escape(data["token"])}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true"
    fn = "#{Time.now.to_date} - #{channel_name} live.mp4".to_filename
  end
  "ffmpeg -i \"#{url}\" -acodec copy -vcodec copy -absf aac_adtstoasc \"#{fn}\""
end

get "/twitch/watch" do
  if /clips\.twitch\.tv\/(?:embed\?clip=)?(?<clip_slug>[^?&#]+)/ =~ params[:url]
    # https://clips.twitch.tv/majinphil/UnusualClamRaccAttack
    # https://clips.twitch.tv/embed?clip=majinphil/UnusualClamRaccAttack&autoplay=false
  elsif /twitch\.tv\/videos\/(?<vod_id>\d+)/ =~ params[:url] or /twitch\.tv\/(?:[^\/]+)\/v\/(?<vod_id>\d+)/ =~ params[:url] or /(^|v)(?<vod_id>\d+)/ =~ params[:url]
    # https://www.twitch.tv/videos/25133028
    # https://www.twitch.tv/gamesdonequick/v/34377308?t=53m40s
    # https://player.twitch.tv/?video=v103620362
  elsif /twitch\.tv\/(?<channel_name>[^\/?#]+)/ =~ params[:url]
    # https://www.twitch.tv/trevperson
  else
    channel_name = params[:url]
  end

  if clip_slug
    response = HTTP.get("https://clips.twitch.tv/embed?clip=#{clip_slug}")
    return "Clip does not seem to exist." if response.code == 404
    raise TwitchError.new(response) if !response.success?
    streams = response.body.scan(/https:\/\/clips-media-assets\.twitch\.tv\/.+?\.mp4/)
    return "Can't find clip." if streams.empty?
  elsif vod_id
    response = TwitchParty.get("/kraken/videos/v#{vod_id}")
    return "Video does not exist." if response.code == 404
    raise TwitchError.new(response) if !response.success?

    response = TwitchParty.get("/api/vods/#{vod_id}/access_token")
    raise TwitchError.new(response) if !response.success?
    data = response.parsed_response
    playlist_url = "http://usher.twitch.tv/vod/#{vod_id}?nauthsig=#{data["sig"]}&nauth=#{CGI.escape(data["token"])}"

    response = HTTP.get(playlist_url)
    streams = response.body.split("\n").reject { |line| line[0] == "#" } + [playlist_url]
  elsif channel_name
    response = TwitchParty.get("/api/channels/#{channel_name}/access_token")
    return "Channel does not seem to exist." if response.code == 404
    raise TwitchError.new(response) if !response.success?

    data = response.parsed_response
    token_data = JSON.parse(data["token"])
    playlist_url = "http://usher.ttvnw.net/api/channel/hls/#{token_data["channel"]}.m3u8?token=#{CGI.escape(data["token"])}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true"

    response = HTTP.get(playlist_url)
    return "Channel does not seem to be online." if response.code == 404
    raise TwitchError.new(response) if !response.success?
    streams = response.body.split("\n").reject { |line| line.start_with?("#") } + [playlist_url]
  end
  if request.user_agent["Mozilla/"]
    redirect "vlc://#{streams[0]}" if params.has_key?("open")
    "Open this url in VLC and it will automatically open the top stream.\nTo open vlc:// links, see: https://github.com/stefansundin/vlc-protocol\n\n#{streams.join("\n")}"
  else
    redirect streams[0]
  end
end

get %r{/twitch/(?<id>\d+)/(?<username>.+)} do |id, username|
  @id = id

  type = %w[all highlight archive].pick(params[:type]) || "all"
  response = TwitchParty.get("/kraken/channels/#{username}/videos", query: { broadcast_type: type })
  raise TwitchError.new(response) if !response.success?

  @data = response.parsed_response["videos"].select { |video| video["status"] != "recording" }
  @username = @data[0]["channel"]["name"] rescue CGI.unescape(username)
  @user = @data[0]["channel"]["display_name"] rescue CGI.unescape(username)

  @title = @user
  @title += "'s highlights" if type == "highlight"
  @title += " on Twitch"

  erb :twitch_feed
end

get "/speedrun" do
  return "Insufficient parameters" if params[:q].empty?

  if /speedrun\.com\/run\/(?<run_id>[^\/?#]+)/ =~ params[:q]
    # https://www.speedrun.com/run/1zx0qkez
    response = SpeedrunParty.get("/runs/#{run_id}")
    raise SpeedrunError.new(response) if !response.success?
    game = response.parsed_response["data"]["game"]
  elsif /speedrun\.com\/(?<game>[^\/?#]+)/ =~ params[:q]
    # https://www.speedrun.com/alttp#No_Major_Glitches
  else
    game = params[:q]
  end

  response = SpeedrunParty.get("/games/#{game}")
  if response.redirect?
    game = response.headers["location"].split("/")[-1]
    response = SpeedrunParty.get("/games/#{game}")
  end
  return "Can't find a game with that name. Sorry." if response.code == 404
  raise SpeedrunError.new(response) if !response.success?
  data = response.parsed_response["data"]

  redirect "/speedrun/#{data["id"]}/#{data["abbreviation"]}"
end

get "/speedrun/:id/:abbr" do |id, abbr|
  @id = id
  @abbr = abbr

  response = SpeedrunParty.get("/runs", query: { status: "verified", orderby: "verify-date", direction: "desc", game: id, embed: "category,players,level,platform,region" })
  raise SpeedrunError.new(response) if !response.success?
  @data = response.parsed_response["data"].reject { |run| run["videos"].nil? }

  erb :speedrun_feed
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
    doc = Nokogiri::HTML(open("http://www.ustream.tv/channel/#{channel_id}"))
    channel_title = doc.at("meta[property='og:title']")["content"]
  rescue
    return "Could not find the channel."
  end

  redirect "/ustream/#{channel_id}/#{channel_title}"
end

get %r{/ustream/(?<id>\d+)/(?<title>.+)} do |id, title|
  @id = id
  @user = CGI.unescape(title)

  response = UstreamParty.get("/channels/#{id}/videos.json")
  raise UstreamError.new(response) if !response.success?
  @data = response.parsed_response["videos"]

  erb :ustream_feed
end

get "/ustream/download" do
  if /ustream\.tv\/recorded\/(?<id>\d+)/ =~ params[:url]
    # http://www.ustream.tv/recorded/74562214
  elsif params[:url].numeric?
    id = params[:url]
  else
    return "Please use a link directly to a video."
  end

  response = UstreamParty.get("/videos/#{id}.json")
  return "Video does not exist." if response.code == 404
  return "#{UstreamParty::BASE_URL}/videos/#{id}.json returned code #{response.code}." if response.code == 401
  raise UstreamError.new(response) if !response.success?
  url = response.parsed_response["video"]["media_urls"]["flv"]
  return "#{UstreamParty::BASE_URL}/videos/#{id}.json: Video flv url is null. This channel is probably protected or something." if url.nil?
  redirect url
end

get "/dailymotion" do
  return "Insufficient parameters" if params[:q].empty?

  if /dailymotion\.com\/video\/(?<video_id>[a-z0-9]+)/ =~ params[:q]
    # http://www.dailymotion.com/video/x3r4xy2_recut-9-cultural-interchange_fun
  elsif /dailymotion\.com\/playlist\/(?<playlist_id>[a-z0-9]+)/ =~ params[:q]
    # http://www.dailymotion.com/playlist/x4bnhu_GeneralGrin_fair-use-recuts/1
  elsif /dailymotion\.com\/(?:(?:followers|subscriptions|playlists\/user|user)\/)?(?<user>[^\/?#]+)/ =~ params[:q]
    # http://www.dailymotion.com/followers/GeneralGrin/1
    # http://www.dailymotion.com/subscriptions/GeneralGrin/1
    # http://www.dailymotion.com/playlists/user/GeneralGrin/1
    # http://www.dailymotion.com/user/GeneralGrin/1
    # http://www.dailymotion.com/GeneralGrin
  else
    # it's probably a username
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

  response = DailymotionParty.get("/user/#{CGI.escape(user)}", query: { fields: "id,username" })
  if response.success?
    user_id = response.parsed_response["id"]
    username = response.parsed_response["username"]
    redirect "/dailymotion/#{user_id}/#{username}"
  else
    "Could not find a user with the name #{user}. Sorry."
  end
end

get %r{/dailymotion/(?<user_id>[a-z0-9]+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id
  @username = CGI.unescape(username)

  response = DailymotionParty.get("/user/#{user_id}/videos", query: { fields: "id,title,created_time,description,allow_embed,available_formats,duration" })
  raise DailymotionError.new(response) if !response.success?
  @data = response.parsed_response["list"]

  erb :dailymotion_feed
end

get "/imgur" do
  return "Insufficient parameters" if params[:q].empty?

  if /imgur\.com\/user\/(?<username>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/user/thebookofgray
  elsif /imgur\.com\/a\/(?<album_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/a/IwyIm
  elsif /(?:(?:imgur|reddit)\.com)?\/?r\/(?<subreddit>[a-zA-Z0-9_]+)/ =~ params[:q]
    # https://imgur.com/r/aww
    # https://www.reddit.com/r/aww
    redirect "/imgur/r/#{subreddit}#{"?#{params[:type]}" if !params[:type].empty?}"
    return
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
    return "Can't identify #{image_id} as an image or gallery." if response.code == 404
    raise ImgurError.new(response) if !response.success?
    user_id = response.parsed_response["data"]["account_id"]
    username = response.parsed_response["data"]["account_url"]
  elsif album_id
    response = ImgurParty.get("/album/#{album_id}")
    return "Can't identify #{album_id} as an album." if response.code == 404
    raise ImgurError.new(response) if !response.success?
    user_id = response.parsed_response["data"]["account_id"]
    username = response.parsed_response["data"]["account_url"]
  elsif username
    response = ImgurParty.get("/account/#{CGI.escape(username)}")
    return "Can't find a user with that name. Sorry. If you want a feed for a subreddit, enter \"r/#{username}\"." if response.code == 404
    raise ImgurError.new(response) if !response.success?
    user_id = response.parsed_response["data"]["id"]
    username = response.parsed_response["data"]["url"]
  end

  if user_id.nil?
    "This image was probably uploaded anonymously. Sorry."
  else
    redirect "/imgur/#{user_id}/#{username}#{"?#{params[:type]}" if !params[:type].empty?}"
  end
end

get "/imgur/:user_id/:username" do
  if params[:user_id] == "r"
    @subreddit = params[:username]
    response = ImgurParty.get("/gallery/r/#{@subreddit}")
  else
    @user_id = params[:user_id]
    @username = params[:username]
    # can't use user_id in this request unfortunately
    response = ImgurParty.get("/account/#{@username}/submissions")
  end
  raise ImgurError.new(response) if !response.success? or response.body.empty?
  @data = response.parsed_response["data"]

  if params[:animated]
    value = params[:animated] == "true"
    @data.select! { |image| image["animated"] == value }
  end
  if params[:nsfw]
    value = params[:nsfw] == "true"
    @data.select! { |image| image["nsfw"] == value }
  end
  if params[:is_album]
    value = params[:is_album] == "true"
    @data.select! { |image| image["is_album"] == value }
  end
  if params[:min_score]
    value = params[:min_score].to_i
    @data.select! { |image| image["score"] >= value }
  end

  erb :imgur_feed
end

get "/svtplay" do
  return "Insufficient parameters" if params[:q].empty?

  if /https?:\/\/(?:www\.)?svtplay\.se\/video\/\d+\/(?<program>[^\/]+)/ =~ params[:q]
    # https://www.svtplay.se/video/7181623/veckans-brott/veckans-brott-sasong-12-avsnitt-10
  elsif /https?:\/\/(www\.)?svtplay\.se\/(?<program>[^\/]+)/ =~ params[:q]
    # https://www.svtplay.se/veckans-brott
  else
    # it's probably a program name
    program = params[:q].downcase.gsub(/[:.]/, "").gsub("", "").gsub(" ", "-")
  end

  if program
    redirect "https://www.svtplay.se/#{program}/atom.xml"
  else
    "Could not find the program. Sorry."
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

  erb :dilbert
end

get "/favicon.ico" do
  redirect "/img/icon32.png"
end

get %r{/apple-touch-icon.*} do
  redirect "/img/icon128.png"
end

get "/opensearch.xml" do
  erb :opensearch
end

if ENV["GOOGLE_VERIFICATION_TOKEN"]
  /(?:google)?(?<google_token>[0-9a-f]+)(?:\.html)?/ =~ ENV["GOOGLE_VERIFICATION_TOKEN"]
  get "/google#{google_token}.html" do
    "google-site-verification: google#{google_token}.html"
  end
end

if ENV["BING_VERIFICATION_TOKEN"]
  get "/BingSiteAuth.xml" do
    <<-EOF.undent
      <?xml version="1.0"?>
      <users>
        <user>#{ENV["BING_VERIFICATION_TOKEN"]}</user>
      </users>
    EOF
  end
end

error do |e|
  status 500
  "Sorry, a nasty error occurred: #{e}"
end

not_found do
  "Sorry, that route does not exist."
end
