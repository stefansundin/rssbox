# frozen_string_literal: true
# export RUBYOPT=--enable-frozen-string-literal

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
  elsif /^https?:\/\/(?:www\.)?(?:periscope|pscp)\.tv/ =~ params[:q]
    redirect "/periscope?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?soundcloud\.com/ =~ params[:q]
    redirect "/soundcloud?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.)?mixcloud\.com/ =~ params[:q]
    redirect "/mixcloud?#{params.to_querystring}"
  elsif /^https?:\/\/(?:www\.|go\.)?twitch\.tv/ =~ params[:q]
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
  elsif /^(?<baseurl>https?:\/\/[a-zA-Z0-9\-]+\.tumblr\.com)/ =~ params[:q]
    redirect "#{baseurl}/rss"
  elsif /^https?:\/\/itunes\.apple\.com\/.+\/id(?<id>\d+)/ =~ params[:q]
    # https://itunes.apple.com/us/podcast/the-bernie-sanders-show/id1223800705
    response = HTTP.get("https://itunes.apple.com/lookup?id=#{id}")
    raise(HTTPError, response) if !response.success?
    redirect response.json["results"][0]["feedUrl"]
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

  response = Twitter.get("/users/lookup.json", query: { screen_name: user })
  return "Can't find a user with that name. Sorry." if response.code == 404
  raise(TwitterError, response) if !response.success?

  user_id = response.json[0]["id_str"]
  screen_name = response.json[0]["screen_name"]
  redirect "/twitter/#{user_id}/#{screen_name}#{"?#{params[:type]}" if !params[:type].empty?}"
end

get %r{/twitter/(?<id>\d+)/(?<username>.+)} do |id, username|
  @user_id = id

  response = Twitter.get("/statuses/user_timeline.json", query: {
    user_id: id,
    count: 100,
    include_rts: params[:include_rts] || "1",
    exclude_replies: params[:exclude_replies] || "0",
    tweet_mode: "extended"
  })
  status response.code
  return response.body if response.code == 401
  return "This user id no longer exists. The user was likely deleted or recreated. Try resubscribing." if response.code == 404
  raise(TwitterError, response) if !response.success?

  @data = response.json
  @username = @data[0]["user"]["screen_name"] rescue CGI.unescape(username)

  if params[:with_media] == "video"
    @data.select! { |t| t["extended_entities"] && t["extended_entities"]["media"].any? { |m| m.has_key?("video_info") } }
  elsif params[:with_media] == "picture"
    @data.select! { |t| t["extended_entities"] && !t["extended_entities"]["media"].any? { |m| m.has_key?("video_info") } }
  elsif params[:with_media]
    @data.select! { |t| t["extended_entities"] }
  end

  erb :twitter_feed
end

get "/youtube" do
  return "Insufficient parameters" if params[:q].empty?

  if /youtube\.com\/channel\/(?<channel_id>(UC|S)[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/channel/UC4a-Gbdw7vOaccHmFo40b9g/videos
    # https://www.youtube.com/channel/SWu5RTwuNMv6U
  elsif /\b(?<channel_id>(?:UC[^\/?#]{22,}|S[^\/?#]{12,}))/ =~ params[:q]
    # it's a channel id
  elsif /youtube\.com\/(?<type>user|c|show)\/(?<slug>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/user/khanacademy/videos
    # https://www.youtube.com/c/khanacademy
    # https://www.youtube.com/show/redvsblue
    # there is no way to resolve these accurately through the API, the best way is to look for the channelId meta tag in the website HTML
    # note that slug != username, e.g. https://www.youtube.com/c/kawaiiguy and https://www.youtube.com/user/kawaiiguy are two different channels
    user = "#{type}/#{slug}"
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
    response = HTTP.get("https://www.youtube.com/#{CGI.escape(user)}")
    if response.redirect?
      # https://www.youtube.com/tyt -> https://www.youtube.com/user/theyoungturks (different from https://www.youtube.com/user/tyt)
      response = HTTP.get(response.redirect_url)
    end
    return "Could not find the user. Please try with a video url instead." if response.code == 404
    raise(GoogleError, response) if !response.success?
    doc = Nokogiri::HTML(response.body)
    channel_id = doc.at("meta[itemprop='channelId']")["content"]
  end

  if video_id
    response = Google.get("/youtube/v3/videos", query: { part: "snippet", id: video_id })
    raise(GoogleError, response) if !response.success?
    if response.json["items"].length > 0
      channel_id = response.json["items"][0]["snippet"]["channelId"]
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

  query = { part: "id", type: "video", order: "date", channelId: @channel_id, maxResults: 50 }
  if params[:q]
    query[:q] = params[:q]
    @title = "\"#{params[:q]}\" from #{@username}"
  else
    @title = "#{@username} on YouTube"
  end

  ids = if params[:eventType]
    params[:eventType].split(",").map do |eventType|
      query[:eventType] = eventType
      response = Google.get("/youtube/v3/search", query: query)
      raise(GoogleError, response) if !response.success?
      response.json["items"]
    end.flatten.uniq { |v| v["id"]["videoId"] }.sort_by { |v| v["snippet"]["publishedAt"] }.reverse
  else
    response = Google.get("/youtube/v3/search", query: query)
    raise(GoogleError, response) if !response.success?
    response.json["items"]
  end.map { |v| v["id"]["videoId"] }

  response = Google.get("/youtube/v3/videos", query: { part: "snippet,liveStreamingDetails", id: ids.join(",") })
  raise(GoogleError, response) if !response.success?
  @data = response.json["items"]

  # The YouTube API can bug out and return videos from other channels even though "channelId" is used, so make doubly sure
  @data.select! { |v| v["snippet"]["channelId"] == @channel_id }

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

  response = Google.get("/plus/v1/people/#{CGI.escape(user)}")
  return "Can't find a page with that name. Sorry." if response.code == 404
  raise(GoogleError, response) if !response.success?
  data = response.json
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

  response = Google.get("/plus/v1/people/#{id}/activities/public")
  raise(GoogleError, response) if !response.success?
  @data = response.json

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
    response = Vimeo.get("/videos/#{video_id}")
    raise(VimeoError, response) if !response.success?
    user_id = response.json["user"]["uri"].gsub("/users/","").to_i
  elsif /vimeo\.com\/(?:channels\/)?(?<user>[^\/]+)/ =~ params[:q] or user = params[:q]
    # it's probably a channel name
    response = Vimeo.get("/users", query: { query: user })
    raise(VimeoError, response) if !response.success?
    if response.json["data"].length > 0
      user_id = response.json["data"][0]["uri"].gsub("/users/","").to_i
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

  response = Facebook.get("/", query: { id: id, metadata: "1" })
  return "Can't find a page with that name. Sorry." if response.code == 404
  return "#{Facebook::BASE_URL}/#{id} returned code #{response.code}." if response.code == 400
  raise(FacebookError, response) if !response.success?
  data = response.json
  if data["metadata"]["fields"].any? { |field| field["name"] == "from" }
    # this is needed if the url is for e.g. a photo and not the main page
    response = Facebook.get("/", query: { id: id, fields: "from", metadata: "1" })
    raise(FacebookError, response) if !response.success?
    id = response.json["from"]["id"]
    response = Facebook.get("/", query: { id: id, metadata: "1" })
    raise(FacebookError, response) if !response.success?
    data = response.json
  end
  if data["metadata"]["fields"].any? { |field| field["name"] == "username" }
    response = Facebook.get("/", query: { id: id, fields: "username,name" })
    raise(FacebookError, response) if !response.success?
    data = response.json
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

  response = Facebook.get("/", query: { id: id, metadata: "1" })
  if response.success?
    type = response.json["metadata"]["type"]
    if type == "video"
      response = Facebook.get("/", query: { id: id, fields: "source,created_time,title,description,live_status,from" })
      status response.code
      data = response.json
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
      response = Facebook.get("/", query: { id: id, fields: "images,created_time,name,from" })
      data = response.json
      image = data["images"][0]
      url = image["source"]
      fn = "#{data["created_time"].to_date} - #{data["name"] || data["from"]["name"]}.jpg".to_filename

      if env["HTTP_ACCEPT"] == "application/json"
        content_type :json
        return {
          url: url,
          filename: fn,
        }.to_json
      end

      redirect url
    else
      return "Unknown type (#{type})."
    end
  else
    if response.json["error"]["code"] == 100
      # The video/photo is probably uploaded by a regular Facebook user (i.e. not uploaded to a page), which we can't get info from via the API.
      # Video example: https://www.facebook.com/ofer.dikovsky/videos/10154633221533413/
      # Photo example: 1401133169914577
      response = Facebook.get("https://www.facebook.com/#{id}")
      response = Facebook.get(response.redirect_url) if response.redirect_same_origin?
      if response.success?
        if /hd_src_no_ratelimit:"(?<url>[^"]+)"/ =~ response.body
        elsif /https:\/\/[^"]+_#{id}_[^"]+\.jpg[^"]+/o =~ response.body
          # This is not the best quality of the picture, but it will have to do
          url = CGI.unescapeHTML($&)
        end
        if /<title[^>]*>(?<title>[^<]+)<\/title>/ =~ response.body and /data-utime="(?<utime>\d+)"/ =~ response.body
          title = title.force_encoding("UTF-8").gsub(" | Facebook", "")
          created_time = Time.at(utime.to_i)
          fn = "#{created_time.to_date} - #{title}.#{url.url_ext}".to_filename
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
      return response.json.to_json
    end
  end
end

get %r{/facebook/(?<id>\d+)/(?<username>.+)} do |id, username|
  @id = id

  @type = @edge = %w[videos photos live].pick(params[:type]) || "posts"
  @edge = "videos" if @type == "live"
  fields = {
    "posts"  => "updated_time,from,parent_id,type,story,name,message,description,link,source,picture,full_picture,properties,with_tags",
    "videos" => "updated_time,from,title,description,embed_html,length,live_status",
    "photos" => "updated_time,from,message,description,name,link,source",
  }[@edge]

  response = Facebook.get("/#{id}/#{@edge}", query: { fields: fields, since: Time.now.to_i-365*24*60*60 }) # date -v -1w +%s
  return "#{Facebook::BASE_URL}/#{id}/#{@edge} returned code #{response.code}." if response.code == 400
  raise(FacebookError, response) if !response.success?

  @data = response.json["data"]
  if @edge == "posts"
    # Filter posts if with=uid is supplied (property only exists on posts)
    if params[:with]
      ids = params[:with].split(",")
      @data.select! { |post| post["with_tags"] and post["with_tags"]["data"].any? { |tag| ids.include?(tag["id"]) } }
    elsif params.has_key?(:with)
      # If with is specified but is nil, then we just want to get posts that include someone else
      @data.select! { |post| post["with_tags"] }
    end

    # Copy down video length from properties array
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
    response = Instagram.get("/p/#{post_id}/")
    return "This post does not exist or is a private post." if response.code == 404
    raise(InstagramError, response) if !response.success?
    user = response.json["graphql"]["shortcode_media"]["owner"]
  elsif params[:q]["instagram.com/explore/"]
    return "This app does not support hashtags. Sorry."
  elsif /instagram\.com\/(?<name>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/infectedmushroom/
  else
    name = params[:q]
  end

  if name
    response = Instagram.get("/#{CGI.escape(name)}/")
    if response.success?
      user = response.json["graphql"]["user"]
    else
      # https://www.instagram.com/web/search/topsearch/?query=infected
      response = Instagram.get("/web/search/topsearch/", query: { query: name })
      raise(InstagramError, response) if !response.success?
      user = response.json["users"][0]["user"]
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

  response = Instagram.get("/p/#{post_id}/")
  return "Please use a URL directly to a post." if !response.success?
  data = response.json["graphql"]["shortcode_media"]

  if env["HTTP_ACCEPT"] == "application/json"
    content_type :json
    status response.code
    created_at = Time.at(data["taken_at_timestamp"])
    caption = data["edge_media_to_caption"]["edges"][0]["node"]["text"] rescue post_id

    if data["edge_sidecar_to_children"]
      return data["edge_sidecar_to_children"]["edges"].map { |edge| edge["node"] }.map.with_index do |node, i|
        url = node["video_url"] || node["display_url"]
        {
          url: url,
          filename: "#{created_at.to_date} - #{data["owner"]["username"]} - #{caption} - #{i+1}#{url.url_ext}".to_filename
        }
      end.to_json
    else
      url = data["video_url"] || data["display_url"]
      return [{
        url: url,
        filename: "#{created_at.to_date} - #{data["owner"]["username"]} - #{caption}#{url.url_ext}".to_filename
      }].to_json
    end
  end

  if data["edge_sidecar_to_children"]
    node = data["edge_sidecar_to_children"]["edges"][0]["node"]
    url = node["video_url"] || node["display_url"]
  else
    url = data["video_url"] || data["display_url"]
  end

  redirect url
end

get %r{/instagram/(?<user_id>\d+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id

  headers = {}
  if params[:sessionid]
    # To subscribe to private feeds, either grab the sessionid cookie from the Chrome devtools (Application -> Cookies -> https://www.instagram.com -> sessionid), or follow these steps in bash:
    # u=your_username
    # p=your_password
    # csrftoken=$(curl -sI https://www.instagram.com/accounts/login/ | grep -i 'set-cookie: csrftoken=' | cut -d';' -f1 | cut -d= -f2)
    # curl -sv https://www.instagram.com/accounts/login/ajax/ -H 'referer: https://www.instagram.com/accounts/login/' -b "csrftoken=$csrftoken" -H "x-csrftoken: $csrftoken" --data "username=$u&password=$p" 2>&1 | grep -i 'set-cookie: sessionid=' | cut -d';' -f1 | cut -d= -f2
    # Then use this value in a query param to this endpoint, e.g:
    # https://rssbox.herokuapp.com/instagram/1234567890/your_friends_username?sessionid=1234...
    # But please host the app yourself if you decide to do this, otherwise you will leak the token to me and the privacy of your friends posts.
    headers["Cookie"] = "sessionid=#{CGI.escape(params[:sessionid])}"
  end

  response = Instagram.get("/#{username}/", headers: headers)
  return "Instagram username does not exist. If the user changed their username, go here to find the new username: https://www.instagram.com/graphql/query/?query_id=17880160963012870&id=#{@user_id}&first=1" if response.code == 404
  return "The sessionid expired!" if params[:sessionid] && response.code == 302
  raise(InstagramError, response) if !response.success?

  @data = response.json["graphql"]["user"]
  @user = @data["username"] rescue CGI.unescape(username)

  type = %w[videos photos].pick(params[:type]) || "posts"
  @data["edge_owner_to_timeline_media"]["edges"].map! do |post|
    if post["node"]["__typename"] == "GraphSidecar"
      post["nodes"] = Instagram.get_post(post["node"]["shortcode"], headers: headers)
    end
    post
  end
  if type == "videos"
    @data["edge_owner_to_timeline_media"]["edges"].select! { |post| post["node"]["is_video"] }
  elsif type == "photos"
    @data["edge_owner_to_timeline_media"]["edges"].select! { |post| !post["node"]["is_video"] }
  end

  @title = @user
  @title += "'s #{type}" if type != "posts"
  @title += " on Instagram"

  erb :instagram_feed
end

get "/periscope" do
  return "Insufficient parameters" if params[:q].empty?

  if /(?:periscope|pscp)\.tv\/w\/(?<broadcast_id>[^\/?#]+)/ =~ params[:q]
    # https://www.periscope.tv/w/1gqxvBmMZdexB
    # https://www.pscp.tv/w/1gqxvBmMZdexB
  elsif /(?:periscope|pscp)\.tv\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.periscope.tv/jimmy_dore
    # https://www.pscp.tv/jimmy_dore
  else
    username = params[:q]
  end

  url = if broadcast_id
    "https://www.periscope.tv/w/#{broadcast_id}"
  else
    "https://www.periscope.tv/#{CGI.escape(username)}"
  end
  response = Periscope.get(url)
  return "That username does not exist." if response.code == 404
  return "That broadcast has expired." if response.code == 410
  raise(PeriscopeError, response) if !response.success?
  doc = Nokogiri::HTML(response.body)
  data = doc.at("div#page-container")["data-store"]
  json = JSON.parse(data)
  username, user_id = json["UserCache"]["usernames"].first

  redirect "/periscope/#{user_id}/#{username}"
end

get %r{/periscope/(?<id>[^/]+)/(?<username>.+)} do |id, username|
  @id = id
  @username = CGI.unescape(username)

  response = Periscope.get_broadcasts(id)
  raise(PeriscopeError, response) if !response.success?
  @data = response.json["broadcasts"]
  @user = if @data.first
    @data.first["user_display_name"]
  else
    @username
  end

  erb :periscope_feed
end

get %r{/periscope_img/(?<broadcast_id>[^/]+)} do |id|
  # The image url expires after 24 hours, so to avoid it being cached by the RSS client and then expire, we just proxy it on demand
  # Interestingly enough, if a request is made before the token expires, it will be cached by their CDN and continue to work even after the token expires
  # Can't just redirect either since it looks at the referer header, and most web based RSS clients will send that
  # For whatever reason, the accessVideoPublic endpoint doesn't require a session_id
  response = Periscope.get("/accessVideoPublic", query: { broadcast_id: id })
  status response.code
  cache_control :public, :max_age => 31556926 # cache a long time
  return "Image not found." if response.code == 404
  raise(PeriscopeError, response) if !response.success?
  response = HTTP.get(response.json["broadcast"]["image_url"])
  content_type response.headers["content-type"].join(", ")
  response.body
end

get "/soundcloud" do
  return "Insufficient parameters" if params[:q].empty?

  if /soundcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://soundcloud.com/infectedmushroom/01-she-zorement?in=infectedmushroom/sets/converting-vegetarians-ii
  else
    username = params[:q]
  end

  response = Soundcloud.get("/resolve", query: { url: "https://soundcloud.com/#{username}" })
  if response.code == 302
    uri = Addressable::URI.parse(response.json["location"])
    return "URL does not resolve to a user." if !uri.path.start_with?("/users/")
    id = uri.path[/\d+/]
  elsif response.code == 404 and username.numeric?
    response = Soundcloud.get("/users/#{username}")
    return "Can't find a user with that id. Sorry." if response.code == 404
    raise(SoundcloudError, response) if !response.success?
    id = response.json["id"]
  elsif response.code == 404
    return "Can't find a user with that name. Sorry."
  else
    raise(SoundcloudError, response)
  end

  response = Soundcloud.get("/users/#{id}")
  raise(SoundcloudError, response) if !response.success?
  data = response.json

  redirect "/soundcloud/#{data["id"]}/#{data["permalink"]}"
end

get "/soundcloud/download" do
  url = params[:url]
  url = "https://#{url}" if !url.start_with?("http:", "https:")
  response = Soundcloud.get("/resolve", query: { url: url })
  return "URL does not resolve." if response.code == 404
  raise(SoundcloudError, response) if response.code != 302
  uri = Addressable::URI.parse(response.json["location"])
  return "URL does not resolve to a track." if !uri.path.start_with?("/tracks/")
  response = Soundcloud.get("#{uri.path}/stream")
  raise(SoundcloudError, response) if response.code != 302
  media_url = response.json["location"]

  if env["HTTP_ACCEPT"] == "application/json"
    response = Soundcloud.get("#{uri.path}")
    content_type :json
    status response.code
    data = response.json
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

  response = Soundcloud.get("/users/#{id}/tracks")
  raise(SoundcloudError, response) if !response.success?

  @data = response.json
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

  response = Mixcloud.get("/#{username}/")
  return "Can't find a user with that name. Sorry." if response.code == 404
  raise(MixcloudError, response) if !response.success?
  data = response.json

  redirect "/mixcloud/#{data["username"]}/#{data["name"]}"
end

get %r{/mixcloud/(?<username>[^/]+)/(?<user>.+)} do |username, user|
  response = Mixcloud.get("/#{username}/cloudcasts/")
  return "That username no longer exist." if response.code == 404
  raise(MixcloudError, response) if !response.success?

  @data = response.json["data"]
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
    response = Twitch.get("/kraken/videos/v#{vod_id}")
    return "Video does not exist." if response.code == 404
    raise(TwitchError, response) if !response.success?
    data = response.json
    username = data["channel"]["name"]
  end

  response = Twitch.get("/kraken/channels/#{username}")
  return "Can't find a user with that name. Sorry." if response.code == 404
  raise(TwitchError, response) if !response.success?
  data = response.json

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
    response = Twitch.get("https://clips.twitch.tv/embed?clip=#{clip_slug}")
    return "Clip does not seem to exist." if response.code == 404
    raise(TwitchError, response) if !response.success?
    url = response.body[/https:\/\/clips-media-assets\.twitch\.tv\/.+?\.mp4/]
    return "Can't find clip." if url.nil?
    redirect url
    return
  elsif vod_id
    response = Twitch.get("/kraken/videos/v#{vod_id}")
    return "Video does not exist." if response.code == 404
    raise(TwitchError, response) if !response.success?
    data = response.json

    response = Twitch.get("/api/vods/#{vod_id}/access_token")
    raise(TwitchError, response) if !response.success?
    vod_data = response.json

    url = "http://usher.twitch.tv/vod/#{vod_id}?nauthsig=#{vod_data["sig"]}&nauth=#{CGI.escape(vod_data["token"])}"
    fn = "#{data["created_at"].to_date} - #{data["channel"]["display_name"]} - #{data["title"]}.mp4".to_filename
  elsif channel_name
    response = Twitch.get("/api/channels/#{channel_name}/access_token")
    return "Channel does not seem to exist." if response.code == 404
    raise(TwitchError, response) if !response.success?

    data = response.json
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
    response = Twitch.get("https://clips.twitch.tv/embed?clip=#{clip_slug}")
    return "Clip does not seem to exist." if response.code == 404
    raise(TwitchError, response) if !response.success?
    streams = response.body.scan(/https:\/\/clips-media-assets\.twitch\.tv\/.+?\.mp4/)
    return "Can't find clip." if streams.empty?
  elsif vod_id
    response = Twitch.get("/kraken/videos/v#{vod_id}")
    return "Video does not exist." if response.code == 404
    raise(TwitchError, response) if !response.success?

    response = Twitch.get("/api/vods/#{vod_id}/access_token")
    raise(TwitchError, response) if !response.success?
    data = response.json
    playlist_url = "http://usher.twitch.tv/vod/#{vod_id}?nauthsig=#{data["sig"]}&nauth=#{CGI.escape(data["token"])}"

    response = Twitch.get(playlist_url)
    streams = response.body.split("\n").reject { |line| line[0] == "#" } + [playlist_url]
  elsif channel_name
    response = Twitch.get("/api/channels/#{channel_name}/access_token")
    return "Channel does not seem to exist." if response.code == 404
    raise(TwitchError, response) if !response.success?

    data = response.json
    token_data = JSON.parse(data["token"])
    playlist_url = "http://usher.ttvnw.net/api/channel/hls/#{token_data["channel"]}.m3u8?token=#{CGI.escape(data["token"])}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true"

    response = Twitch.get(playlist_url)
    return "Channel does not seem to be online." if response.code == 404
    raise(TwitchError, response) if !response.success?
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
  response = Twitch.get("/kraken/channels/#{username}/videos", query: { broadcast_type: type })
  raise(TwitchError, response) if !response.success?

  @data = response.json["videos"].select { |video| video["status"] != "recording" }
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
    response = Speedrun.get("/runs/#{run_id}")
    raise(SpeedrunError, response) if !response.success?
    game = response.json["data"]["game"]
  elsif /speedrun\.com\/(?<game>[^\/?#]+)/ =~ params[:q]
    # https://www.speedrun.com/alttp#No_Major_Glitches
  else
    game = params[:q]
  end

  response = Speedrun.get("/games/#{game}")
  if response.redirect?
    game = response.headers["location"][0].split("/")[-1]
    response = Speedrun.get("/games/#{game}")
  end
  return "Can't find a game with that name. Sorry." if response.code == 404
  raise(SpeedrunError, response) if !response.success?
  data = response.json["data"]

  redirect "/speedrun/#{data["id"]}/#{data["abbreviation"]}"
end

get "/speedrun/:id/:abbr" do |id, abbr|
  @id = id
  @abbr = abbr

  response = Speedrun.get("/runs", query: { status: "verified", orderby: "verify-date", direction: "desc", game: id, embed: "category,players,level,platform,region" })
  raise(SpeedrunError, response) if !response.success?
  @data = response.json["data"].reject { |run| run["videos"].nil? }

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

  response = Ustream.get("/channels/#{id}/videos.json")
  raise(UstreamError, response) if !response.success?
  @data = response.json["videos"]

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

  response = Ustream.get("/videos/#{id}.json")
  return "Video does not exist." if response.code == 404
  return "#{Ustream::BASE_URL}/videos/#{id}.json returned code #{response.code}." if response.code == 401
  raise(UstreamError, response) if !response.success?
  url = response.json["video"]["media_urls"]["flv"]
  return "#{Ustream::BASE_URL}/videos/#{id}.json: Video flv url is null. This channel is probably protected or something." if url.nil?
  redirect url
end

get "/dailymotion" do
  return "Insufficient parameters" if params[:q].empty?

  if /dailymotion\.com\/video\/(?<video_id>[a-zA-Z0-9]+)/ =~ params[:q] or /dai\.ly\/(?<video_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # http://www.dailymotion.com/video/x3r4xy2_recut-9-cultural-interchange_fun
    # http://www.dailymotion.com/video/k1ZotianZxwzm6fmny2
    # http://dai.ly/x4bzwj4?start=60
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
    response = Dailymotion.get("/video/#{video_id}")
    raise(DailymotionError, response) if !response.success?
    user = response.json["owner"]
  elsif playlist_id
    response = Dailymotion.get("/playlist/#{playlist_id}")
    raise(DailymotionError, response) if !response.success?
    user = response.json["owner"]
  end

  response = Dailymotion.get("/user/#{CGI.escape(user)}", query: { fields: "id,username" })
  if response.success?
    user_id = response.json["id"]
    username = response.json["username"]
    redirect "/dailymotion/#{user_id}/#{username}"
  else
    "Could not find a user with the name #{user}. Sorry."
  end
end

get %r{/dailymotion/(?<user_id>[a-z0-9]+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id
  @username = CGI.unescape(username)

  response = Dailymotion.get("/user/#{user_id}/videos", query: { fields: "id,title,created_time,description,allow_embed,available_formats,duration" })
  raise(DailymotionError, response) if !response.success?
  @data = response.json["list"]

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
    response = Imgur.get("/gallery/image/#{image_id}")
    response = Imgur.get("/image/#{image_id}") if !response.success?
    return "Can't identify #{image_id} as an image or gallery." if !response.success?
    raise(ImgurError, response) if !response.success?
    user_id = response.json["data"]["account_id"]
    username = response.json["data"]["account_url"]
  elsif album_id
    response = Imgur.get("/album/#{album_id}")
    return "Can't identify #{album_id} as an album." if response.code == 404
    raise(ImgurError, response) if !response.success?
    user_id = response.json["data"]["account_id"]
    username = response.json["data"]["account_url"]
  elsif username
    response = Imgur.get("/account/#{CGI.escape(username)}")
    return "Can't find a user with that name. Sorry. If you want a feed for a subreddit, enter \"r/#{username}\"." if response.code == 404
    raise(ImgurError, response) if !response.success?
    user_id = response.json["data"]["id"]
    username = response.json["data"]["url"]
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
    response = Imgur.get("/gallery/r/#{@subreddit}")
  else
    @user_id = params[:user_id]
    @username = params[:username]
    # can't use user_id in this request unfortunately
    response = Imgur.get("/account/#{@username}/submissions")
  end
  raise(ImgurError, response) if !response.success? or response.body.empty?
  @data = response.json["data"]

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
  @feed = Feedjira::Feed.fetch_and_parse("http://feeds.dilbert.com/DilbertDailyStrip")
  @entries = @feed.entries.map do |entry|
    data = $redis.get("dilbert:#{entry.id}")
    if data
      data = JSON.parse(data)
    else
      og = OpenGraph.new("http://dilbert.com/strip/#{entry.id}")
      data = {
        "image" => og.images.first,
        "title" => og.title,
        "description" => og.description,
      }
      $redis.setex("dilbert:#{entry.id}", 60*60*24*30, data.to_json)
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
    <<~EOF
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
