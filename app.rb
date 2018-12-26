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
  send_file File.join(settings.public_folder, "live.html")
end

get "/countdown" do
  content_type :html
  SecureHeaders.use_secure_headers_override(request, :countdown)
  send_file File.join(settings.public_folder, "countdown.html")
end

get "/go" do
  return [400, "Insufficient parameters"] if params[:q].empty?

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
  elsif /^https?:\/\/(?:[a-z0-9]+\.)?imgur\.com/ =~ params[:q]
    redirect "/imgur?#{params.to_querystring}"
  elsif /^https?:\/\/\medium\.com\/(?<user>@?[^\/?&#]+)/ =~ params[:q]
    redirect "https://medium.com/feed/#{user}"
  elsif /^https?:\/\/(?<name>[a-z0-9\-]+)\.blogspot\./ =~ params[:q]
    redirect "https://#{name}.blogspot.com/feeds/posts/default"
  elsif /^https?:\/\/groups\.google\.com\/forum\/#!(?:[a-z]+)\/(?<name>[^\/?&#]+)/ =~ params[:q]
    redirect "https://groups.google.com/forum/feed/#{name}/msgs/atom.xml?num=50"
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
    return [404, "Unknown service"]
  end
end

get "/twitter" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if params[:q]["twitter.com/i/"] || params[:q]["twitter.com/who_to_follow/"]
    return [404, "Unsupported url. Sorry."]
  elsif params[:q]["twitter.com/hashtag/"]
    return [404, "This app does not support hashtags. Sorry."]
  elsif /twitter\.com\/intent\/.+[?&]user_id=(?<user_id>\d+)/ =~ params[:q]
    # https://twitter.com/intent/user?user_id=34313404
    # https://twitter.com/intent/user?user_id=71996998
  elsif /twitter\.com\/(?:#!\/|@)?(?<user>[^\/?#]+)/ =~ params[:q] || /@(?<user>[^\/?#]+)/ =~ params[:q]
    # https://twitter.com/#!/infected
    # https://twitter.com/infected
    # @username
  else
    # it's probably a username
    user = params[:q]
  end

  if user
    query = { screen_name: user }
  elsif user_id
    query = { user_id: user_id }
  end

  response = Twitter.get("/users/show.json", query: query)
  return [response.code, response.json["errors"][0]["message"]] if response.json["errors"]
  raise(TwitterError, response) if !response.success?

  user_id = response.json["id_str"]
  screen_name = response.json["screen_name"].or(response.json["name"])
  redirect "/twitter/#{user_id}/#{screen_name}#{"?#{params[:type]}" if !params[:type].empty?}"
end

get %r{/twitter/(?<id>\d+)/(?<username>.+)} do |id, username|
  @user_id = id

  response = Twitter.get("/statuses/user_timeline.json", query: {
    user_id: id,
    count: 100,
    tweet_mode: "extended",
    include_rts: %w[0 1].pick(params[:include_rts]) || "1",
    exclude_replies: %w[0 1].pick(params[:exclude_replies]) || "0",
  })
  return [response.code, response.body] if response.code == 401
  return [response.code, "This user id no longer exists. The user was likely deleted or recreated. Try resubscribing."] if response.code == 404
  raise(TwitterError, response) if !response.success?

  @data = response.json
  if @data[0] && !@data[0]["user"]["screen_name"].empty?
    @username = @data[0]["user"]["screen_name"]
  else
    @username = CGI.unescape(username)
  end

  if params[:with_media] == "video"
    @data.select! { |t| t["extended_entities"] && t["extended_entities"]["media"].any? { |m| m.has_key?("video_info") } }
  elsif params[:with_media] == "picture"
    @data.select! { |t| t["extended_entities"] && !t["extended_entities"]["media"].any? { |m| m.has_key?("video_info") } }
  elsif params[:with_media]
    @data.select! { |t| t["extended_entities"] }
  end

  @data.map do |t|
    t = t["retweeted_status"] if t.has_key?("retweeted_status")
    t["entities"]["urls"].each do |entity|
      t["full_text"].gsub!(entity["url"], entity["expanded_url"])
    end
    t["full_text"].grep_urls
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :twitter_feed
end

get "/youtube" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /youtube\.com\/channel\/(?<channel_id>(UC|S)[^\/?#]+)(?:\/search\?query=(?<query>[^&#]+))?/ =~ params[:q]
    # https://www.youtube.com/channel/UC4a-Gbdw7vOaccHmFo40b9g/videos
    # https://www.youtube.com/channel/SWu5RTwuNMv6U
    # https://www.youtube.com/channel/UCd6MoB9NC6uYN2grvUNT-Zg/search?query=aurora
  elsif /youtube\.com\/(?<type>user|c|show)\/(?<slug>[^\/?#]+)(?:\/search\?query=(?<query>[^&#]+))?/ =~ params[:q]
    # https://www.youtube.com/user/khanacademy/videos
    # https://www.youtube.com/c/khanacademy
    # https://www.youtube.com/show/redvsblue
    # https://www.youtube.com/user/AmazonWebServices/search?query=aurora
    # https://www.youtube.com/c/khanacademy/search?query=Frequency+stability
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
  elsif /\b(?<channel_id>(?:UC[^\/?#]{22,}|S[^\/?#]{12,}))/ =~ params[:q]
    # it's a channel id
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
    return [response.code, "Could not find the user. Please try with a video url instead."] if response.code == 404
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

  if query || params[:type]
    # it's no longer possible to get usernames using the API
    # note that the values include " - YouTube" at the end if the User-Agent is a browser
    og = OpenGraph.new("https://www.youtube.com/channel/#{channel_id}")
    username = og.url.split("/")[-1]
    username = og.title if username == channel_id
  end

  if query
    redirect "/youtube/#{channel_id}/#{CGI.escape(username)}?q=#{CGI.escape(query)}"
  elsif params[:type] == "live"
    url = "/youtube/#{channel_id}/#{CGI.escape(username)}?eventType=live,upcoming"
    url += "&tz=#{params[:tz]}" if params[:tz]
    redirect url
  elsif channel_id
    redirect "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel_id}"
  elsif playlist_id
    redirect "https://www.youtube.com/feeds/videos.xml?playlist_id=#{playlist_id}"
  else
    return [404, "Could not find the channel. Sorry."]
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
    eventTypes = params[:eventType].split(",")
    if eventTypes.any? { |type| !%w[completed live upcoming].include?(type) }
      return [400, "Invalid eventType. Valid types: completed live upcoming."]
    end
    eventTypes.map do |eventType|
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

  response = Google.get("/youtube/v3/videos", query: { part: "snippet,liveStreamingDetails,contentDetails", id: ids.join(",") })
  raise(GoogleError, response) if !response.success?
  @data = response.json["items"]

  # filter out all live streams that are not completed if we don't specifically want specific event types
  if !params[:eventType]
    @data.select! { |v| !v["liveStreamingDetails"] || v["liveStreamingDetails"]["actualEndTime"] }
  end

  # The YouTube API can bug out and return videos from other channels even though "channelId" is used, so make doubly sure
  @data.select! { |v| v["snippet"]["channelId"] == @channel_id }

  if params[:q]
    q = params[:q].downcase
    @data.select! { |v| v["snippet"]["title"].downcase[q] }
  end

  @data.map do |video|
    video["snippet"]["description"].grep_urls
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :youtube_feed
end

get "/googleplus" do
  return [400, "Insufficient parameters"] if params[:q].empty?
  params[:q] = params[:q].gsub(" ", "+") # spaces in urls is a mess

  if /plus\.google\.com\/(u\/\d+\/)?(?<user>\+[a-zA-Z0-9]+)/ =~ params[:q]
    # https://plus.google.com/+TIME
  elsif /plus\.google\.com\/(u\/\d+\/)?(?<user>\d+)/ =~ params[:q]
    # https://plus.google.com/112161921284629501085
  else
    # it's probably a username
    user = params[:q]
    user = "+#{user}" if user[0] != "+" && !user.numeric?
  end

  response = Google.get("/plus/v1/people/#{CGI.escape(user)}")
  return [response.code, "Can't find a page with that name. Sorry."] if response.code == 404
  raise(GoogleError, response) if !response.success?
  data = response.json
  user_id = data["id"]
  if /\/\+(?<user>[a-zA-Z0-9]+)$/ =~ data["url"]
    username = user
  else
    username = data["displayName"]
  end

  redirect "/googleplus/#{user_id}/#{CGI.escape(username)}"
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

  @data["items"].map do |post|
    post["object"]["body"] = CGI.unescapeHTML(post["object"]["content"]).gsub("<br />", "\n").strip_tags
    post["object"]["body"].grep_urls
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :googleplus_feed
end

get "/vimeo" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /vimeo\.com\/user(?<user_id>\d+)/ =~ params[:q]
    # https://vimeo.com/user7103699
  elsif /vimeo\.com\/ondemand\/(?<user>[^\/?&#]+)/ =~ params[:q]
    # https://vimeo.com/ondemand/thealphaquadrant/
    response = Vimeo.get("/ondemand/pages/#{user}")
    raise(VimeoError, response) if !response.success?
    user_id = response.json["user"]["uri"][/\d+/]
  elsif /vimeo\.com\/(?<video_id>\d+)/ =~ params[:q]
    # https://vimeo.com/155672086
    response = Vimeo.get("/videos/#{video_id}")
    raise(VimeoError, response) if !response.success?
    user_id = response.json["user"]["uri"][/\d+/]
  elsif /vimeo\.com\/(?:channels\/)?(?<user>[^\/?&#]+)/ =~ params[:q] || user = params[:q]
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
    return [404, "Could not find the channel. Sorry."]
  end
end

get "/facebook" do
  return [404, "Facebook credentials not configured"] if ENV["FACEBOOK_APP_ID"].empty? || ENV["FACEBOOK_APP_SECRET"].empty?
  return [400, "Insufficient parameters"] if params[:q].empty?
  params[:q].gsub!("facebookcorewwwi.onion", "facebook.com") if params[:q]["facebookcorewwwi.onion"]

  if /https:\/\/www\.facebook\.com\/plugins\/.+[?&]href=(?<href>.+)$/ =~ params[:q]
    # https://www.facebook.com/plugins/video.php?href=https%3A%2F%2Fwww.facebook.com%2Finfectedmushroom%2Fvideos%2F10154638763917261%2F&show_text=0&width=400
    params[:q] = CGI.unescape(href)
  end

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
  return [response.code, "Can't find a page with that name. Sorry."] if response.code == 404
  return [response.code, "#{Facebook::BASE_URL}/#{id} returned code #{response.code}."] if response.code == 400
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

  return [404, "Please use a link directly to the Facebook page."] if !data["id"].numeric?
  redirect "/facebook/#{data["id"]}/#{data["username"] || data["name"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
end

get "/facebook/download" do
  return [404, "Facebook credentials not configured"] if ENV["FACEBOOK_APP_ID"].empty? || ENV["FACEBOOK_APP_SECRET"].empty?

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
          live: (data["live_status"] == "LIVE"),
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
      return [404, "Unknown type (#{type})."]
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
        if /<title[^>]*>(?<title>[^<]+)<\/title>/ =~ response.body && /data-utime="(?<utime>\d+)"/ =~ response.body
          title = title.force_encoding("UTF-8").gsub(" | Facebook", "")
          created_time = Time.at(utime.to_i)
          fn = "#{created_time.to_date} - #{title}.#{url.url_ext}".to_filename
        end
        if url
          if env["HTTP_ACCEPT"] == "application/json"
            content_type :json
            return {
              url: url,
              filename: fn,
            }.to_json
          end
          redirect url
        else
          return [404, "Video/photo not found."]
        end
      else
        return [response.code, "https://www.facebook.com/#{id} returned #{response.code}"]
      end
    else
      return [response.code, response.json.to_json]
    end
  end
end

get %r{/facebook/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [404, "Facebook credentials not configured"] if ENV["FACEBOOK_APP_ID"].empty? || ENV["FACEBOOK_APP_SECRET"].empty?

  @id = id
  @type = @edge = %w[videos photos live].pick(params[:type]) || "posts"
  @edge = "videos" if @type == "live"
  fields = {
    "posts"  => "updated_time,from,parent_id,type,story,name,message,description,link,source,picture,full_picture,properties",
    "videos" => "updated_time,from,title,description,embed_html,length,live_status",
    "photos" => "updated_time,from,message,description,name,link,source",
  }[@edge]

  query = { fields: fields, since: Time.now.to_i-365*24*60*60 } # date -v -1w +%s

  if params[:locale]
    query[:locale] = params[:locale]
  end

  response = Facebook.get("/#{id}/#{@edge}", query: query)
  return [response.code, "#{Facebook::BASE_URL}/#{id}/#{@edge} returned code #{response.code}."] if response.code == 400
  raise(FacebookError, response) if !response.success?

  @data = response.json["data"]
  if @edge == "posts"
    # Copy down video length from properties array
    @data.each do |post|
      if post["properties"]
        post["properties"].each do |prop|
          if prop["name"] == "Length" && /^(?<m>\d+):(?<s>\d+)$/ =~ prop["text"]
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

  @data.map do |post|
    post.slice("message", "description", "link").values.map(&:grep_urls)
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :facebook_feed
end

get "/instagram" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /instagram\.com\/p\/(?<post_id>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/p/4KaPsKSjni/
    response = Instagram.get("/p/#{post_id}/")
    return [response.code, "This post does not exist or is a private post."] if response.code == 404
    raise(InstagramError, response) if !response.success?
    user = response.json["graphql"]["shortcode_media"]["owner"]
  elsif params[:q]["instagram.com/explore/"]
    return [404, "This app does not support hashtags. Sorry."]
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
    return [404, "Can't find a user with that name. Sorry."]
  end
end

get "/instagram/download" do
  if /instagram\.com\/p\/(?<post_id>[^\/?#]+)/ =~ params[:url]
    # https://www.instagram.com/p/4KaPsKSjni/
  else
    post_id = params[:url]
  end

  response = Instagram.get("/p/#{post_id}/")
  return [404, "Please use a URL directly to a post."] if !response.success?
  data = response.json["graphql"]["shortcode_media"]

  if env["HTTP_ACCEPT"] == "application/json"
    content_type :json
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
        filename: "#{created_at.to_date} - #{data["owner"]["username"]} - #{caption}#{url.url_ext}".to_filename,
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

  options = nil
  tokens = nil
  if params[:csrftoken] && params[:rhx_gis] && params[:sessionid]
    # To subscribe to private feeds, follow these steps in bash:
    # u=your_username
    # p=your_password
    # your_friends_username=your_friends_username
    # your_friends_userid=$(curl -s "https://www.instagram.com/$your_friends_username/" | grep -oE '"id":"([0-9]+)"' | cut -d'"' -f4)
    # ua="Mozilla/5.0 (Windows NT 6.1; WOW64; rv:59.0) Gecko/20100101 Firefox/59.0"
    # csrftoken=$(curl -sI https://www.instagram.com/ -A "$ua" | grep -i 'set-cookie: csrftoken=' | cut -d';' -f1 | cut -d= -f2)
    # rhx_gis=$(curl -s https://www.instagram.com/ -A "$ua" -b "csrftoken=$csrftoken" | grep -oE '"rhx_gis":"([A-Za-z0-9]+)"' | cut -d'"' -f4)
    # sessionid=$(curl -sv https://www.instagram.com/accounts/login/ajax/ -A "$ua" -H 'referer: https://www.instagram.com/accounts/login/' -b "csrftoken=$csrftoken" -H "x-csrftoken: $csrftoken" --data "username=$u&password=$p" 2>&1 | grep -i 'set-cookie: sessionid=' | cut -d';' -f1 | cut -d= -f2)
    # echo "https://rssbox.herokuapp.com/instagram/$your_friends_userid/$your_friends_username?csrftoken=$csrftoken&rhx_gis=$rhx_gis&sessionid=$sessionid"
    # Please host the app yourself if you decide to do this, otherwise you will leak the tokens to me and the privacy of your friends posts.
    options = {
      headers: {"Cookie" => "sessionid=#{CGI.escape(params[:sessionid])}"}
    }
    tokens = {
      csrftoken: params[:csrftoken],
      rhx_gis: params[:rhx_gis],
    }
  end

  response = Instagram.get("/#{username}/", options, tokens)
  return [response.code, "Instagram username does not exist. If the user changed their username, go here to find the new username: https://www.instagram.com/graphql/query/?query_id=17880160963012870&id=#{@user_id}&first=1"] if response.code == 404
  return [401, "The sessionid expired!"] if params[:sessionid] && response.code == 302
  raise(InstagramError, response) if !response.success? || !response.json

  @data = response.json["graphql"]["user"]
  @user = @data["username"] rescue CGI.unescape(username)

  type = %w[videos photos].pick(params[:type]) || "posts"
  @data["edge_owner_to_timeline_media"]["edges"].map! do |post|
    if post["node"]["__typename"] == "GraphSidecar"
      post["nodes"] = Instagram.get_post(post["node"]["shortcode"], options, tokens)
    else
      post["nodes"] = [post["node"]]
    end
    post
  end
  if type == "videos"
    @data["edge_owner_to_timeline_media"]["edges"].select! { |post| post["nodes"].any? { |node| node["is_video"] } }
  elsif type == "photos"
    @data["edge_owner_to_timeline_media"]["edges"].select! { |post| !post["nodes"].any? { |node| node["is_video"] } }
  end

  @title = @user
  @title += "'s #{type}" if type != "posts"
  @title += " on Instagram"

  @data["edge_owner_to_timeline_media"]["edges"].select do |post|
    post["node"]["edge_media_to_caption"]["edges"][0]
  end.map do |post|
    post["node"]["edge_media_to_caption"]["edges"][0]["node"]["text"].grep_urls
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :instagram_feed
end

get "/periscope" do
  return [400, "Insufficient parameters"] if params[:q].empty?

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
  return [response.code, "That username does not exist."] if response.code == 404
  return [response.code, "That broadcast has expired."] if response.code == 410
  return [response.code, "Please enter a username."] if response.code/100 == 4
  raise(PeriscopeError, response) if !response.success?
  doc = Nokogiri::HTML(response.body)
  data = doc.at("div#page-container")["data-store"]
  json = JSON.parse(data)
  username, user_id = json["UserCache"]["usernames"].first

  redirect "/periscope/#{user_id}/#{CGI.escape(username)}"
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
  cache_control :public, :max_age => 31556926 # cache a long time
  return [response.code, "Image not found."] if response.code == 404
  raise(PeriscopeError, response) if !response.success?
  if response.json["broadcast"]["image_url"].empty?
    return [404, "Image not found."]
  end
  response = HTTP.get(response.json["broadcast"]["image_url"])
  content_type response.headers["content-type"][0]
  response.body
end

get "/soundcloud" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /soundcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://soundcloud.com/infectedmushroom/01-she-zorement?in=infectedmushroom/sets/converting-vegetarians-ii
  else
    username = params[:q]
  end

  response = Soundcloud.get("/resolve", query: { url: "https://soundcloud.com/#{username}" })
  if response.code == 302
    uri = Addressable::URI.parse(response.json["location"])
    return [404, "URL does not resolve to a user."] if !uri.path.start_with?("/users/")
    id = uri.path[/\d+/]
  elsif response.code == 404 && username.numeric?
    response = Soundcloud.get("/users/#{username}")
    return [response.code, "Can't find a user with that id. Sorry."] if response.code == 404
    raise(SoundcloudError, response) if !response.success?
    id = response.json["id"]
  elsif response.code == 404
    return [response.code, "Can't find a user with that name. Sorry."]
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
  return [response.code, "URL does not resolve."] if response.code == 404
  raise(SoundcloudError, response) if response.code != 302
  uri = Addressable::URI.parse(response.json["location"])
  return [404, "URL does not resolve to a track."] if !uri.path.start_with?("/tracks/")
  response = Soundcloud.get("#{uri.path}/stream")
  raise(SoundcloudError, response) if response.code != 302
  media_url = response.json["location"]

  if env["HTTP_ACCEPT"] == "application/json"
    response = Soundcloud.get("#{uri.path}")
    content_type :json
    data = response.json
    created_at = Time.parse(data["created_at"])
    return {
      url: media_url,
      filename: "#{created_at.to_date} - #{data["title"]}.mp3".to_filename,
    }.to_json
  end

  redirect media_url
end

get %r{/soundcloud/(?<id>\d+)/(?<username>.+)} do |id, username|
  @id = id

  response = Soundcloud.get("/users/#{id}/tracks")
  return [404, "That user no longer exist."] if response.code == 500 && response.body == '{"error":"Match failed"}'
  raise(SoundcloudError, response) if !response.success?

  @data = response.json
  @username = @data[0]["user"]["permalink"] rescue CGI.unescape(username)
  @user = @data[0]["user"]["username"] rescue CGI.unescape(username)

  @data.map do |track|
    track["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| URL.resolve(urls) }

  erb :soundcloud_feed
end

get "/mixcloud" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /mixcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.mixcloud.com/infected-live/infected-mushroom-liveedc-las-vegas-21-5-2014/
  else
    username = params[:q]
  end

  response = Mixcloud.get("/#{username}/")
  return [response.code, "Can't find a user with that name. Sorry."] if response.code == 404
  raise(MixcloudError, response) if !response.success?
  data = response.json

  redirect "/mixcloud/#{data["username"]}/#{CGI.escape(data["name"])}"
end

get %r{/mixcloud/(?<username>[^/]+)/(?<user>.+)} do |username, user|
  response = Mixcloud.get("/#{username}/cloudcasts/")
  return [response.code, "That username no longer exist."] if response.code == 404
  raise(MixcloudError, response) if !response.success?

  @data = response.json["data"]
  @username = @data[0]["user"]["username"] rescue CGI.unescape(username)
  @user = @data[0]["user"]["name"] rescue CGI.unescape(user)

  erb :mixcloud_feed
end

get "/twitch" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /twitch\.tv\/directory\/game\/(?<game_name>[^\/?#]+)/ =~ params[:q]
    # https://www.twitch.tv/directory/game/Perfect%20Dark
  elsif /twitch\.tv\/directory/ =~ params[:q]
    # https://www.twitch.tv/directory/all/tags/7cefbf30-4c3e-4aa7-99cd-70aabb662f27
    return [404, "Unsupported url. Sorry."]
  elsif /twitch\.tv\/videos\/(?<vod_id>\d+)/ =~ params[:q]
    # https://www.twitch.tv/videos/25133028
  elsif /twitch\.tv\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.twitch.tv/majinphil
    # https://www.twitch.tv/gsl/video/25133028 (legacy url)
  else
    username = params[:q]
  end

  if game_name
    response = Twitch.get("/games", query: { name: game_name })
    raise(TwitchError, response) if !response.success?
    data = response.json["data"][0]
    return [404, "Can't find a game with that name."] if data.nil?
    redirect "/twitch/directory/game/#{data["id"]}/#{game_name}#{"?type=#{params[:type]}" if !params[:type].empty?}"
  elsif vod_id
    response = Twitch.get("/videos", query: { id: vod_id })
    return [response.code, "Video does not exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?
    data = response.json["data"][0]
    redirect "/twitch/#{data["user_id"]}/#{data["user_name"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
  else
    response = Twitch.get("/users", query: { login: username })
    return [response.code, "The username contains invalid characters."] if response.code == 400
    raise(TwitchError, response) if !response.success?
    data = response.json["data"][0]
    return [404, "Can't find a user with that name. Sorry."] if data.nil?
    redirect "/twitch/#{data["id"]}/#{data["display_name"]}#{"?type=#{params[:type]}" if !params[:type].empty?}"
  end
end

get "/twitch/download" do
  return [400, "Insufficient parameters"] if params[:url].empty?

  if /twitch\.tv\/[^\/]+\/clip\/(?<clip_slug>[^?&#]+)/ =~ params[:url] || /clips\.twitch\.tv\/(?:embed\?clip=)?(?<clip_slug>[^?&#]+)/ =~ params[:url]
    # https://www.twitch.tv/majinphil/clip/TenaciousCreativePieNotATK
    # https://clips.twitch.tv/DignifiedThirstyDogYee
    # https://clips.twitch.tv/majinphil/UnusualClamRaccAttack (legacy url, redirects to the one above)
    # https://clips.twitch.tv/embed?clip=DignifiedThirstyDogYee&autoplay=false
  elsif /twitch\.tv\/(?:[^\/]+\/)?(?:v|videos?)\/(?<vod_id>\d+)/ =~ params[:url] || /(?:^|v)(?<vod_id>\d+)/ =~ params[:url]
    # https://www.twitch.tv/videos/25133028
    # https://www.twitch.tv/gsl/video/25133028 (legacy url)
    # https://www.twitch.tv/gamesdonequick/video/34377308?t=53m40s
    # https://www.twitch.tv/gamesdonequick/v/34377308?t=53m40s (legacy url)
    # https://player.twitch.tv/?video=v103620362 ("v" is optional)
  elsif /twitch\.tv\/(?<channel_name>[^\/?#]+)/ =~ params[:url]
    # https://www.twitch.tv/trevperson
  else
    channel_name = params[:url]
  end

  if clip_slug
    response = HTTP.get("https://clips.twitch.tv/api/v2/clips/#{clip_slug}/status")
    return [response.code, "Clip does not seem to exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?
    url = response.json["quality_options"][0]["source"]
    return [404, "Can't find clip."] if url.nil?
    redirect url
    return
  elsif vod_id
    response = Twitch.get("/videos", query: { id: vod_id })
    return [response.code, "Video does not exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?
    data = response.json["data"][0]

    response = TwitchToken.get("/vods/#{vod_id}/access_token")
    raise(TwitchError, response) if !response.success?
    vod_data = response.json

    url = "http://usher.twitch.tv/vod/#{vod_id}?nauthsig=#{vod_data["sig"]}&nauth=#{CGI.escape(vod_data["token"])}"
    fn = "#{data["created_at"].to_date} - #{data["user_name"]} - #{data["title"]}.mp4".to_filename
  elsif channel_name
    response = TwitchToken.get("/channels/#{channel_name}/access_token")
    return [response.code, "Channel does not seem to exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?

    data = response.json
    token_data = JSON.parse(data["token"])

    url = "http://usher.ttvnw.net/api/channel/hls/#{token_data["channel"]}.m3u8?token=#{CGI.escape(data["token"])}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true"
    fn = "#{Time.now.to_date} - #{token_data["channel"]} live.mp4".to_filename
  end
  "ffmpeg -i '#{url}' -acodec copy -vcodec copy -absf aac_adtstoasc '#{fn}'"
end

get "/twitch/watch" do
  return [400, "Insufficient parameters"] if params[:url].empty?

  if /twitch\.tv\/[^\/]+\/clip\/(?<clip_slug>[^?&#]+)/ =~ params[:url] || /clips\.twitch\.tv\/(?:embed\?clip=)?(?<clip_slug>[^?&#]+)/ =~ params[:url]
    # https://www.twitch.tv/majinphil/clip/TenaciousCreativePieNotATK
    # https://clips.twitch.tv/DignifiedThirstyDogYee
    # https://clips.twitch.tv/majinphil/UnusualClamRaccAttack (legacy url, redirects to the one above)
    # https://clips.twitch.tv/embed?clip=DignifiedThirstyDogYee&autoplay=false
  elsif /twitch\.tv\/(?:[^\/]+\/)?(?:v|videos?)\/(?<vod_id>\d+)/ =~ params[:url] || /(?:^|v)(?<vod_id>\d+)/ =~ params[:url]
    # https://www.twitch.tv/gsl/video/25133028
    # https://www.twitch.tv/gamesdonequick/video/34377308?t=53m40s
    # https://www.twitch.tv/videos/25133028 (legacy url)
    # https://www.twitch.tv/gamesdonequick/v/34377308?t=53m40s (legacy url)
    # https://player.twitch.tv/?video=v103620362
  elsif /twitch\.tv\/(?<channel_name>[^\/?#]+)/ =~ params[:url]
    # https://www.twitch.tv/trevperson
  else
    channel_name = params[:url]
  end

  if clip_slug
    response = HTTP.get("https://clips.twitch.tv/api/v2/clips/#{clip_slug}/status")
    return [response.code, "Clip does not seem to exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?
    streams = response.json["quality_options"].map { |s| s["source"] }
    return [404, "Can't find clip."] if streams.empty?
  elsif vod_id
    response = TwitchToken.get("/vods/#{vod_id}/access_token")
    return [response.code, "Video does not exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?
    data = response.json
    playlist_url = "http://usher.twitch.tv/vod/#{vod_id}?nauthsig=#{data["sig"]}&nauth=#{CGI.escape(data["token"])}"

    response = HTTP.get(playlist_url)
    streams = response.body.split("\n").reject { |line| line[0] == "#" } + [playlist_url]
  elsif channel_name
    response = TwitchToken.get("/channels/#{channel_name}/access_token")
    return [response.code, "Channel does not seem to exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?

    data = response.json
    token_data = JSON.parse(data["token"])
    playlist_url = "http://usher.ttvnw.net/api/channel/hls/#{token_data["channel"]}.m3u8?token=#{CGI.escape(data["token"])}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true"

    response = HTTP.get(playlist_url)
    return [response.code, "Channel does not seem to be online."] if response.code == 404
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

get %r{/twitch/directory/game/(?<id>\d+)/(?<game_name>.+)} do |id, game_name|
  @id = id
  @type = "game"

  type = %w[all upload archive highlight].pick(params[:type]) || "all"
  response = Twitch.get("/videos", query: { game_id: id, type: type })
  raise(TwitchError, response) if !response.success?

  @data = response.json["data"]
  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/directory/game/#{game_name}").normalize.to_s

  # live broadcasts show up here too, and the simplest way of filtering them out seems to be to see if thumbnail_url is populated or not
  @data.reject! { |v| v["thumbnail_url"].empty? }

  @title = game_name
  @title += " highlights" if type == "highlight"
  @title += " on Twitch"

  @data.map do |video|
    video["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| URL.resolve(urls) }

  erb :twitch_feed
end

get %r{/twitch/(?<id>\d+)/(?<user>.+)} do |id, user|
  @id = id
  @type = "user"

  type = %w[all upload archive highlight].pick(params[:type]) || "all"
  response = Twitch.get("/videos", query: { user_id: id, type: type })
  raise(TwitchError, response) if !response.success?

  @data = response.json["data"]
  user = @data[0]["user_name"] || CGI.unescape(user)
  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/#{user.downcase}").normalize.to_s

  # live broadcasts show up here too, and the simplest way of filtering them out seems to be to see if thumbnail_url is populated or not
  @data.reject! { |v| v["thumbnail_url"].empty? }

  @title = user
  @title += "'s highlights" if type == "highlight"
  @title += " on Twitch"

  @data.map do |video|
    video["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| URL.resolve(urls) }

  erb :twitch_feed
end

get "/speedrun" do
  return [400, "Insufficient parameters"] if params[:q].empty?

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
  return [response.code, "Can't find a game with that name. Sorry."] if response.code == 404
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

  @data.map do |run|
    [
      run["videos"]["links"].map { |link| link["uri"] },
      run["videos"]["text"],
      run["comment"],
    ].flatten.compact.map(&:grep_urls)
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :speedrun_feed
end

get "/ustream" do
  return [400, "Insufficient parameters"] if params[:q].empty?

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
    return [404, "Could not find the channel."]
  end

  redirect "/ustream/#{channel_id}/#{CGI.escape(channel_title)}"
end

get %r{/ustream/(?<id>\d+)/(?<title>.+)} do |id, title|
  @id = id
  @user = CGI.unescape(title)

  response = Ustream.get("/channels/#{id}/videos.json")
  raise(UstreamError, response) if !response.success?
  @data = response.json["videos"]

  @data.map do |video|
    video["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| URL.resolve(urls) }

  erb :ustream_feed
end

get "/ustream/download" do
  if /ustream\.tv\/recorded\/(?<id>\d+)/ =~ params[:url]
    # http://www.ustream.tv/recorded/74562214
  elsif params[:url].numeric?
    id = params[:url]
  else
    return [404, "Please use a link directly to a video."]
  end

  response = Ustream.get("/videos/#{id}.json")
  return [response.code, "Video does not exist."] if response.code == 404
  return [response.code, "#{Ustream::BASE_URL}/videos/#{id}.json returned code #{response.code}."] if response.code == 401
  raise(UstreamError, response) if !response.success?
  url = response.json["video"]["media_urls"]["flv"]
  return [404, "#{Ustream::BASE_URL}/videos/#{id}.json: Video flv url is null. This channel is probably protected or something."] if url.nil?
  redirect url
end

get "/dailymotion" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /dailymotion\.com\/video\/(?<video_id>[a-zA-Z0-9]+)/ =~ params[:q] || /dai\.ly\/(?<video_id>[a-zA-Z0-9]+)/ =~ params[:q]
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
    redirect "/dailymotion/#{user_id}/#{CGI.escape(username)}"
  else
    return [404, "Could not find a user with the name #{user}. Sorry."]
  end
end

get %r{/dailymotion/(?<user_id>[a-z0-9]+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id
  @username = CGI.unescape(username)

  response = Dailymotion.get("/user/#{user_id}/videos", query: { fields: "id,title,created_time,description,allow_embed,available_formats,duration" })
  return [response.code, "That user no longer exist."] if response.code == 404
  raise(DailymotionError, response) if !response.success?
  @data = response.json["list"]

  erb :dailymotion_feed
end

get "/imgur" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /imgur\.com\/user\/(?<username>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/user/thebookofgray
  elsif /imgur\.com\/a\/(?<album_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/a/IwyIm
  elsif /(?:(?:imgur|reddit)\.com)?\/?r\/(?<subreddit>[a-zA-Z0-9_]+)/ =~ params[:q]
    # https://imgur.com/r/aww
    # https://www.reddit.com/r/aww
    redirect "/imgur/r/#{CGI.escape(subreddit)}#{"?#{params[:type]}" if !params[:type].empty?}"
    return
  elsif /(?<username>[a-zA-Z0-9]+)\.imgur\.com/ =~ params[:q] && username != "i"
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
    return [404, "Can't identify #{image_id} as an image or gallery."] if !response.success?
    raise(ImgurError, response) if !response.success?
    user_id = response.json["data"]["account_id"]
    username = response.json["data"]["account_url"]
  elsif album_id
    response = Imgur.get("/album/#{album_id}")
    return [response.code, "Can't identify #{album_id} as an album."] if response.code == 404
    raise(ImgurError, response) if !response.success?
    user_id = response.json["data"]["account_id"]
    username = response.json["data"]["account_url"]
  elsif username
    response = Imgur.get("/account/#{CGI.escape(username)}")
    return [response.code, "Can't find a user with that name. Sorry. If you want a feed for a subreddit, enter \"r/#{username}\"."] if response.code == 404
    raise(ImgurError, response) if !response.success?
    user_id = response.json["data"]["id"]
    username = response.json["data"]["url"]
  end

  if user_id.nil?
    return [404, "This image was probably uploaded anonymously. Sorry."]
  else
    redirect "/imgur/#{user_id}/#{CGI.escape(username)}#{"?#{params[:type]}" if !params[:type].empty?}"
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
  raise(ImgurError, response) if !response.success? || response.body.empty?
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

  @data.map do |image|
    image["description"]
  end.flatten.compact.map(&:grep_urls).flatten.tap { |urls| URL.resolve(urls) }

  erb :imgur_feed
end

get "/svtplay" do
  return [400, "Insufficient parameters"] if params[:q].empty?

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
    return [404, "Could not find the program. Sorry."]
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

get "/health" do
  if $redis.ping != "PONG"
    return [500, "Redis error"]
  end
rescue Redis::CannotConnectError => e
  return [500, "Redis connection error"]
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
  [500, "Sorry, a nasty error occurred: #{e}"]
end

error Sinatra::NotFound do
  content_type :text
  [404, "Sorry, that route does not exist."]
end
