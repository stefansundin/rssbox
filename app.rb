# frozen_string_literal: true
# export RUBYOPT=--enable-frozen-string-literal

require "sinatra"
require "./config/application"
require "open-uri"

before do
  content_type :text
end

after do
  if env["HTTP_ACCEPT"] == "application/json" && @response.redirect?
    content_type :json
    status 200
    location = @response.headers["Location"]
    @response.headers.delete("Location")
    if location.start_with?(@request.root_url)
      location = location[@request.root_url.length..]
    end
    body location.to_json
  end

  if headers["Content-Type"].start_with?("text/calendar")
    headers({
      "Content-Transfer-Encoding" => "binary",
      "Content-Disposition" => "attachment; filename=\"#{@title}.ics\"",
    })
  end
end

get "/" do
  SecureHeaders.use_secure_headers_override(request, :index)
  erb :index
end

get "/live" do
  return [410, "Disabled since this experiment is no longer maintained."]
  content_type :html
  SecureHeaders.use_secure_headers_override(request, :live)
  send_file File.join(settings.views, "live.html")
end

get "/countdown.html" do
  content_type :html
  SecureHeaders.use_secure_headers_override(request, :countdown)
  send_file File.join(settings.views, "countdown.html")
end

get "/twitch-embed.html" do
  content_type :html
  cache_control :public, :max_age => 31556926 # cache a long time
  SecureHeaders.use_secure_headers_override(request, :twitch_embed)
  send_file File.join(settings.views, "twitch-embed.html")
end

# This route is useful together with this bookmarklet:
# javascript:location='https://rssbox.herokuapp.com/go?q='+encodeURIComponent(location.href);
# Or for Firefox:
# javascript:location='https://rssbox.herokuapp.com/?go='+encodeURIComponent(location.href);
get "/go" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /^https?:\/\/(?:mobile\.)?twitter\.com\// =~ params[:q]
    redirect Addressable::URI.new(path: "/twitter", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.|gaming\.)?youtu(?:\.be|be\.com)/ =~ params[:q]
    redirect Addressable::URI.new(path: "/youtube", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?instagram\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/instagram", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?(?:periscope|pscp)\.tv/ =~ params[:q]
    redirect Addressable::URI.new(path: "/periscope", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?soundcloud\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/soundcloud", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?mixcloud\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/mixcloud", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.|go\.)?twitch\.tv/ =~ params[:q]
    redirect Addressable::URI.new(path: "/twitch", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?speedrun\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/speedrun", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?ustream\.tv/ =~ params[:q]
    redirect Addressable::URI.new(path: "/ustream", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?dailymotion\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/dailymotion", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:www\.)?vimeo\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/vimeo", query_values: params).normalize.to_s
  elsif /^https?:\/\/(?:[a-z0-9]+\.)?imgur\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/imgur", query_values: params).normalize.to_s
  elsif /^https?:\/\/medium\.com\/(?<user>@?[^\/?&#]+)/ =~ params[:q]
    redirect Addressable::URI.parse("https://medium.com/feed/#{user}").normalize.to_s
  elsif /^https?:\/\/(?<name>[a-z0-9\-]+)\.blogspot\./ =~ params[:q]
    redirect Addressable::URI.parse("https://#{name}.blogspot.com/feeds/posts/default").normalize.to_s
  elsif /^https?:\/\/groups\.google\.com\/(?:forum\/[^#]*#!(?:[a-z]+)|g)\/(?<name>[^\/?&#]+)/ =~ params[:q]
    # https://groups.google.com/forum/?oldui=1#!forum/rabbitmq-users
    # https://groups.google.com/forum/?oldui=1#!topic/rabbitmq-users/9D4BAuud6PU
    # https://groups.google.com/g/rabbitmq-users
    # https://groups.google.com/g/rabbitmq-users/c/9D4BAuud6PU
    redirect Addressable::URI.parse("https://groups.google.com/forum/feed/#{name}/msgs/atom.xml?num=50").normalize.to_s
  elsif /^https?:\/\/www\.deviantart\.com\/(?<user>[^\/]+)/ =~ params[:q]
    redirect "https://backend.deviantart.com/rss.xml" + Addressable::URI.new(query: "type=deviation&q=by:#{user} sort:time").normalize.to_s
  elsif /^(?<baseurl>https?:\/\/[a-zA-Z0-9\-]+\.tumblr\.com)/ =~ params[:q]
    redirect "#{baseurl}/rss"
  elsif /^https?:\/\/(?:itunes|podcasts)\.apple\.com\/.+\/id(?<id>\d+)/ =~ params[:q]
    # https://podcasts.apple.com/us/podcast/the-bernie-sanders-show/id1223800705
    response = HTTP.get("https://itunes.apple.com/lookup?id=#{id}")
    raise(HTTPError, response) if !response.success?
    redirect response.json["results"][0]["feedUrl"]
  elsif /^https?:\/\/(?:www\.)?svtplay\.se/ =~ params[:q]
    redirect Addressable::URI.new(path: "/svtplay", query_values: params).normalize.to_s
  else
    return [404, "Unknown service"]
  end
end

get "/twitter" do
  return [404, "Credentials not configured"] if !ENV["TWITTER_ACCESS_TOKEN"]
  return [400, "Insufficient parameters"] if params[:q].empty?

  if params[:q].include?("twitter.com/i/") || params[:q].include?("twitter.com/who_to_follow/")
    return [404, "Unsupported url. Sorry."]
  elsif params[:q].include?("twitter.com/hashtag/") || params[:q].start_with?("#")
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
  return [response.code, response.json["errors"][0]["message"]] if response.json.has_key?("errors")
  raise(TwitterError, response) if !response.success?

  user_id = response.json["id_str"]
  screen_name = response.json["screen_name"].or(response.json["name"])
  redirect Addressable::URI.new(path: "/twitter/#{user_id}/#{screen_name}", query: params[:type]).normalize.to_s
end

get %r{/twitter/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [404, "Credentials not configured"] if !ENV["TWITTER_ACCESS_TOKEN"]

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

  erb :"twitter.atom"
end

get "/youtube" do
  return [404, "Credentials not configured"] if !ENV["GOOGLE_API_KEY"]
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
    response = HTTP.get("https://www.youtube.com/#{user}")
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
    query = CGI.unescape(query) # youtube uses + here instead of %20
    redirect Addressable::URI.new(path: "/youtube/#{channel_id}/#{username}", query_values: { q: query }.merge(params.slice(:tz))).normalize.to_s
  elsif channel_id
    redirect "https://www.youtube.com/feeds/videos.xml" + Addressable::URI.new(query: "channel_id=#{channel_id}").normalize.to_s
  elsif playlist_id
    redirect "https://www.youtube.com/feeds/videos.xml" + Addressable::URI.new(query: "playlist_id=#{playlist_id}").normalize.to_s
  else
    return [404, "Could not find the channel. Sorry."]
  end
end

get "/youtube/:channel_id/:username.ics" do
  return [404, "Credentials not configured"] if !ENV["GOOGLE_API_KEY"]

  @channel_id = params[:channel_id]
  @username = params[:username]
  @title = "#{@username} on YouTube"

  # The API is really inconsistent in listing scheduled live streams, but the RSS endpoint seems to consistently list them, so experiment with using that
  response = HTTP.get("https://www.youtube.com/feeds/videos.xml?channel_id=#{@channel_id}")
  raise(GoogleError, response) if !response.success?
  doc = Nokogiri::XML(response.body)
  ids = doc.xpath("//yt:videoId").map(&:text)

  response = Google.get("/youtube/v3/videos", query: { part: "snippet,liveStreamingDetails,contentDetails", id: ids.join(",") })
  raise(GoogleError, response) if !response.success?
  @data = response.json["items"]

  if params.has_key?(:eventType)
    eventTypes = params[:eventType].split(",")
    eventType_completed = eventTypes.include?("completed")
    eventType_live = eventTypes.include?("live")
    eventType_upcoming = eventTypes.include?("upcoming")
    @data.select! do |v|
      v.has_key?("liveStreamingDetails") && (
        (eventType_completed && v["liveStreamingDetails"].has_key?("actualEndTime")) ||
        (eventType_live      && v["liveStreamingDetails"].has_key?("actualStartTime")    && !v["liveStreamingDetails"].has_key?("actualEndTime")) ||
        (eventType_upcoming  && v["liveStreamingDetails"].has_key?("scheduledStartTime") && !v["liveStreamingDetails"].has_key?("actualStartTime"))
      )
    end
  end

  if params.has_key?(:q)
    @query = params[:q]
    q = @query.downcase
    @data.select! { |v| v["snippet"]["title"].downcase.include?(q) }
  end

  @data.sort_by! do |video|
    if video.has_key?("liveStreamingDetails")
      Time.parse(video["liveStreamingDetails"]["actualStartTime"] || video["liveStreamingDetails"]["scheduledStartTime"])
    else
      Time.parse(video["snippet"]["publishedAt"])
    end
  end.reverse!

  erb :"youtube.ics"
end

get "/youtube/:channel_id/:username" do
  return [404, "Credentials not configured"] if !ENV["GOOGLE_API_KEY"]

  @channel_id = params[:channel_id]
  playlist_id = "UU" + @channel_id[2..]
  @username = params[:username]
  if params.has_key?(:tz)
    if params[:tz].tz_offset?
      @tz = params[:tz]
    elsif TZInfo::Timezone.all_identifiers.include?(params[:tz])
      @tz = TZInfo::Timezone.get(params[:tz])
    end
  end

  # The results from this query are not sorted by publishedAt for whatever reason.. probably due to some uploads being scheduled to be published at a certain time
  response = Google.get("/youtube/v3/playlistItems", query: { part: "snippet", playlistId: playlist_id, maxResults: 10 })
  return [response.code, "It seems like this channel no longer exists."] if response.code == 404
  raise(GoogleError, response) if !response.success?
  ids = response.json["items"].sort_by { |v| Time.parse(v["snippet"]["publishedAt"]) }.reverse.map { |v| v["snippet"]["resourceId"]["videoId"] }

  response = Google.get("/youtube/v3/videos", query: { part: "snippet,liveStreamingDetails,contentDetails", id: ids.join(",") })
  raise(GoogleError, response) if !response.success?
  @data = response.json["items"]

  if params.has_key?(:eventType)
    eventTypes = params[:eventType].split(",")
    eventType_completed = eventTypes.include?("completed")
    eventType_live = eventTypes.include?("live")
    eventType_upcoming = eventTypes.include?("upcoming")
    @data.select! do |v|
      v.has_key?("liveStreamingDetails") && (
        (eventType_completed && v["liveStreamingDetails"].has_key?("actualEndTime")) ||
        (eventType_live      && v["liveStreamingDetails"].has_key?("actualStartTime")    && !v["liveStreamingDetails"].has_key?("actualEndTime")) ||
        (eventType_upcoming  && v["liveStreamingDetails"].has_key?("scheduledStartTime") && !v["liveStreamingDetails"].has_key?("actualStartTime"))
      )
    end
  else
    # filter out all live streams that are not completed if we don't specifically want specific event types
    @data.select! { |v| !v["liveStreamingDetails"] || v["liveStreamingDetails"]["actualEndTime"] }
  end

  if params.has_key?(:q)
    @query = params[:q]
    q = @query.downcase
    @data.select! { |v| v["snippet"]["title"].downcase.include?(q) }
    @title = "\"#{@query}\" from #{@username}"
  else
    @title = "#{@username} on YouTube"
  end

  @data.map do |video|
    video["snippet"]["description"].grep_urls
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :"youtube.atom"
end

get %r{/googleplus/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [410, "RIP Google+ 2011-2019"]
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

get %r{/facebook/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [410, "Facebook functionality has been removed since I do not have API access. Maybe we can rebuild it some day, but using scraping techniques or something."]
end

get "/instagram" do
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /instagram\.com\/(?:p|tv)\/(?<post_id>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/p/B-Pv6COFOjV/
    # https://www.instagram.com/tv/B-Pv6COFOjV/
    response = Instagram.get("/p/#{post_id}/")
    return [response.code, "This post does not exist or is a private post."] if response.code == 404
    raise(InstagramError, response) if !response.success?
    user = response.json["graphql"]["shortcode_media"]["owner"]
  elsif params[:q].include?("instagram.com/explore/") || params[:q].start_with?("#")
    return [404, "This app does not support hashtags. Sorry."]
  elsif /instagram\.com\/(?<name>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/infectedmushroom/
  else
    name = params[:q][/[^\/?#]+/]
  end

  if name
    response = Instagram.get("/#{name}/")
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
    redirect Addressable::URI.new(path: "/instagram/#{user["id"] || user["pk"]}/#{user["username"]}").normalize.to_s
  else
    return [404, "Can't find a user with that name. Sorry."]
  end
end

get "/instagram/download" do
  if /instagram\.com\/(?:p|tv)\/(?<post_id>[^\/?#]+)/ =~ params[:url]
    # https://www.instagram.com/p/B-Pv6COFOjV/
    # https://www.instagram.com/tv/B-Pv6COFOjV/
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

    if data.has_key?("edge_sidecar_to_children")
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

  if data.has_key?("edge_sidecar_to_children")
    node = data["edge_sidecar_to_children"]["edges"][0]["node"]
    url = node["video_url"] || node["display_url"]
  else
    url = data["video_url"] || data["display_url"]
  end

  redirect url
end

get %r{/instagram/(?<user_id>\d+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id

  # To find the query_hash, simply use the Instagram website and monitor the network calls.
  # This request in particular is the one that gets the next page when you scroll down on a profile, but we change it to get the first 12 posts instead of the second or third page.
  options = {
    query: { query_hash: "f045d723b6f7f8cc299d62b57abd500a", variables: "{\"id\":\"#{@user_id}\",\"first\":12}"},
  }
  if params[:sessionid]
    # To subscribe to private feeds, see https://github.com/stefansundin/rssbox/issues/21#issuecomment-525130553
    # Please host the app yourself if you decide to do this, otherwise you will leak your sessionid to me and the privacy of your friends posts.
    options[:headers] = {"Cookie" => "ig_cb=1; sessionid=#{CGI.escape(params[:sessionid])}"}
  end

  response = Instagram.get("/graphql/query/", options)
  return [401, "The sessionid expired!"] if params.has_key?(:sessionid) && response.code == 302
  return [response.code, "Instagram user does not exist."] if !response.json["data"]["user"]
  raise(InstagramError, response) if !response.success? || !response.json?

  @data = response.json["data"]["user"]
  @user = CGI.unescape(username)

  type = %w[videos photos].pick(params[:type]) || "posts"
  @data["edge_owner_to_timeline_media"]["edges"].map! do |post|
    if post["node"]["__typename"] == "GraphSidecar"
      post["nodes"] = Instagram.get_post(post["node"]["shortcode"], options)
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

  erb :"instagram.atom"
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
    "https://www.periscope.tv/#{username}"
  end
  response = Periscope.get(url)
  return [response.code, "That username does not exist."] if response.code == 404
  return [response.code, "That broadcast has expired."] if response.code == 410
  return [response.code, "Please enter a username."] if response.code/100 == 4
  raise(PeriscopeError, response) if !response.success?
  doc = Nokogiri::HTML(response.body)
  data = doc.at("div#page-container")["data-store"]
  json = JSON.parse(data)
  username, user_id = json["UserCache"]["usernames"].to_a[0]

  redirect Addressable::URI.new(path: "/periscope/#{user_id}/#{username}").normalize.to_s
end

get %r{/periscope/(?<id>[^/]+)/(?<username>.+)} do |id, username|
  @id = id
  @username = CGI.unescape(username)

  response = Periscope.get_broadcasts(id)
  raise(PeriscopeError, response) if !response.success?
  @data = response.json["broadcasts"]
  @user = if @data.length > 0
    @data[0]["user_display_name"]
  else
    @username
  end

  erb :"periscope.atom"
end

get %r{/periscope_img/(?<broadcast_id>[^/]+)} do |id|
  # The image URL expires after 24 hours, so to avoid the URL from being cached by the RSS client and then expire, we just redirect on demand
  # Interestingly enough, if a request is made before the token expires, it will be cached by their CDN and continue to work even after the token expires
  response = Periscope.get("/accessVideoPublic", query: { broadcast_id: id })
  cache_control :public, :max_age => 31556926 # cache a long time
  return [response.code, "Image not found."] if response.code == 404
  raise(PeriscopeError, response) if !response.success?
  redirect response.json["broadcast"]["image_url"]
end

get "/soundcloud" do
  return [404, "Credentials not configured"] if !ENV["SOUNDCLOUD_CLIENT_ID"]
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /soundcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://soundcloud.com/infectedmushroom/01-she-zorement?in=infectedmushroom/sets/converting-vegetarians-ii
  else
    username = params[:q]
  end

  response = Soundcloud.get("/resolve", query: { url: "https://soundcloud.com/#{username}" })
  if response.code == 200
    data = response.json
    data = data["user"] if data.has_key?("user")
    return [404, "Can't identify the user."] if data["kind"] != "user"
  elsif response.code == 404 && username.numeric?
    response = Soundcloud.get("/users/#{username}")
    return [response.code, "Can't find a user with that id. Sorry."] if response.code == 400 || response.code == 404
    raise(SoundcloudError, response) if !response.success?
    data = response.json
  elsif response.code == 404
    return [response.code, "Can't find a user with that name. Sorry."]
  else
    raise(SoundcloudError, response)
  end

  redirect Addressable::URI.new(path: "/soundcloud/#{data["id"]}/#{data["permalink"]}").normalize.to_s
end

get "/soundcloud/download" do
  return [404, "Credentials not configured"] if !ENV["SOUNDCLOUD_CLIENT_ID"]

  url = params[:url]
  url = "https://#{url}" if !url.start_with?("http:", "https:")
  response = Soundcloud.get("/resolve", query: { url: url })
  return [response.code, "URL does not resolve."] if response.code == 404
  raise(SoundcloudError, response) if response.code != 200

  data = response.json
  return [404, "URL does not resolve to a track."] if data["kind"] != "track"

  data_uri = Addressable::URI.parse(data["media"]["transcodings"][0]["url"])
  response = Soundcloud.get(data_uri.path)
  raise(SoundcloudError, response) if response.code != 200

  url = response.json["url"]
  fn = "#{Date.parse(data["created_at"])} - #{data["title"]}.mp3".to_filename

  "ffmpeg -i '#{url}' -acodec copy '#{fn}'"
end

get %r{/soundcloud/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [404, "Credentials not configured"] if !ENV["SOUNDCLOUD_CLIENT_ID"]

  @id = id

  response = Soundcloud.get("/users/#{id}/tracks")
  return [404, "That user no longer exist."] if response.code == 500 && response.body == '{"error":"Match failed"}'
  raise(SoundcloudError, response) if !response.success?

  @data = response.json["collection"]
  @username = @data[0]["user"]["permalink"] rescue CGI.unescape(username)
  @user = @data[0]["user"]["username"] rescue CGI.unescape(username)

  @data.map do |track|
    track["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| URL.resolve(urls) }

  erb :"soundcloud.atom"
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

  redirect Addressable::URI.new(path: "/mixcloud/#{data["username"]}/#{data["name"]}").normalize.to_s
end

get %r{/mixcloud/(?<username>[^/]+)/(?<user>.+)} do |username, user|
  response = Mixcloud.get("/#{username}/cloudcasts/")
  return [response.code, "That username no longer exist."] if response.code == 404
  raise(MixcloudError, response) if !response.success?

  @data = response.json["data"]
  @username = @data[0]["user"]["username"] rescue CGI.unescape(username)
  @user = @data[0]["user"]["name"] rescue CGI.unescape(user)

  erb :"mixcloud.atom"
end

get "/twitch" do
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /twitch\.tv\/directory\/game\/(?<game_name>[^\/?#]+)/ =~ params[:q]
    # https://www.twitch.tv/directory/game/Perfect%20Dark
    game_name = Addressable::URI.unescape(game_name)
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
    redirect Addressable::URI.new(path: "/twitch/directory/game/#{data["id"]}/#{game_name}").normalize.to_s
  elsif vod_id
    response = Twitch.get("/videos", query: { id: vod_id })
    return [response.code, "Video does not exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?
    data = response.json["data"][0]
    redirect Addressable::URI.new(path: "/twitch/#{data["user_id"]}/#{data["user_name"]}").normalize.to_s
  else
    response = Twitch.get("/users", query: { login: username })
    return [response.code, "The username contains invalid characters."] if response.code == 400
    raise(TwitchError, response) if !response.success?
    data = response.json["data"][0]
    return [404, "Can't find a user with that name. Sorry."] if data.nil?
    redirect Addressable::URI.new(path: "/twitch/#{data["id"]}/#{data["display_name"]}").normalize.to_s
  end
end

get "/twitch/download" do
  return [404, "Credentials not configured"] if !ENV["TWITCHTOKEN_CLIENT_ID"]
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

    url = "http://usher.twitch.tv" + Addressable::URI.new(path: "/vod/#{vod_id}", query: "nauthsig=#{vod_data["sig"]}&nauth=#{vod_data["token"]}").normalize.to_s
    fn = "#{Date.parse(data["created_at"])} - #{data["user_name"]} - #{data["title"]}.mp4".to_filename
  elsif channel_name
    response = TwitchToken.get("/channels/#{channel_name}/access_token")
    return [response.code, "Channel does not seem to exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?

    data = response.json
    token_data = JSON.parse(data["token"])

    url = "http://usher.ttvnw.net" + Addressable::URI.new(path: "/api/channel/hls/#{token_data["channel"]}.m3u8", query: "token=#{data["token"]}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true").normalize.to_s
    fn = "#{Time.now.to_date} - #{token_data["channel"]} live.mp4".to_filename
  end
  "ffmpeg -i '#{url}' -acodec copy -vcodec copy -absf aac_adtstoasc '#{fn}'"
end

get "/twitch/watch" do
  return [404, "Credentials not configured"] if !ENV["TWITCHTOKEN_CLIENT_ID"]
  return [400, "Insufficient parameters"] if params[:url].empty?

  if /twitch\.tv\/[^\/]+\/clip\/(?<clip_slug>[^?&#]+)/ =~ params[:url] || /clips\.twitch\.tv\/(?:embed\?clip=)?(?<clip_slug>[^?&#]+)/ =~ params[:url]
    # https://www.twitch.tv/majinphil/clip/TenaciousCreativePieNotATK
    # https://clips.twitch.tv/DignifiedThirstyDogYee
    # https://clips.twitch.tv/majinphil/UnusualClamRaccAttack (deprecated url)
    # https://clips.twitch.tv/embed?clip=DignifiedThirstyDogYee&autoplay=false
  elsif /twitch\.tv\/(?:[^\/]+\/)?(?:v|videos?)\/(?<vod_id>\d+)/ =~ params[:url] || /(?:^|v)(?<vod_id>\d+)/ =~ params[:url]
    # https://www.twitch.tv/videos/25133028
    # https://www.twitch.tv/gsl/video/25133028 (legacy url)
    # https://www.twitch.tv/gamesdonequick/video/34377308?t=53m40s (legacy url)
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
    playlist_url = "http://usher.twitch.tv" + Addressable::URI.new(path: "/vod/#{vod_id}", query: "nauthsig=#{data["sig"]}&nauth=#{data["token"]}").normalize.to_s

    response = HTTP.get(playlist_url)
    return [response.code, "Video does not exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?
    streams = response.body.split("\n").reject { |line| line[0] == "#" } + [playlist_url]
  elsif channel_name
    response = TwitchToken.get("/channels/#{channel_name}/access_token")
    return [response.code, "Channel does not seem to exist."] if response.code == 404
    raise(TwitchError, response) if !response.success?

    data = response.json
    token_data = JSON.parse(data["token"])
    playlist_url = "http://usher.ttvnw.net" + Addressable::URI.new(path: "/api/channel/hls/#{token_data["channel"]}.m3u8", query: "token=#{data["token"]}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true").normalize.to_s

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
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

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

  erb :"twitch.atom"
end

get %r{/twitch/(?<id>\d+)/(?<user>.+)\.ics} do |id, user|
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

  @title = "#{user} on Twitch"

  type = %w[all upload archive highlight].pick(params[:type]) || "all"
  response = Twitch.get("/videos", query: { user_id: id, type: type })
  raise(TwitchError, response) if !response.success?

  @data = response.json["data"]
  user = @data[0]["user_name"] || CGI.unescape(user)
  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/#{user.downcase}").normalize.to_s

  erb :"twitch.ics"
end

get %r{/twitch/(?<id>\d+)/(?<user>.+)} do |id, user|
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

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

  erb :"twitch.atom"
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

  redirect Addressable::URI.new(path: "/speedrun/#{data["id"]}/#{data["abbreviation"]}").normalize.to_s
end

get "/speedrun/:id/:abbr" do |id, abbr|
  @id = id
  @abbr = abbr

  response = Speedrun.get("/runs", query: { status: "verified", orderby: "verify-date", direction: "desc", game: id, embed: "category,players,level,platform,region" })
  raise(SpeedrunError, response) if !response.success?
  @data = response.json["data"].reject { |run| run["videos"].nil? }

  @data.map do |run|
    [
      run["videos"]["links"]&.map { |link| link["uri"] },
      run["videos"]["text"],
      run["comment"],
    ].flatten.compact.map(&:grep_urls)
  end.flatten.tap { |urls| URL.resolve(urls) }

  erb :"speedrun.atom"
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
    doc = Nokogiri::HTML(URI.open(url))
    channel_id = doc.at("meta[name='ustream:channel_id']")["content"].to_i
    doc = Nokogiri::HTML(URI.open("http://www.ustream.tv/channel/#{channel_id}"))
    channel_title = doc.at("meta[property='og:title']")["content"]
  rescue
    return [404, "Could not find the channel."]
  end

  redirect Addressable::URI.new(path: "/ustream/#{channel_id}/#{channel_title}").normalize.to_s
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

  erb :"ustream.atom"
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

  response = Dailymotion.get("/user/#{user}", query: { fields: "id,username" })
  if response.success?
    redirect Addressable::URI.new(path: "/dailymotion/#{response.json["id"]}/#{response.json["username"]}").normalize.to_s
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

  erb :"dailymotion.atom"
end

get "/imgur" do
  return [404, "Credentials not configured"] if !ENV["IMGUR_CLIENT_ID"]
  return [400, "Insufficient parameters"] if params[:q].empty?

  if /imgur\.com\/user\/(?<username>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/user/thebookofgray
  elsif /imgur\.com\/a\/(?<album_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/a/IwyIm
  elsif /(?:^\/?r\/|(?:imgur|reddit)\.com\/r\/)(?<subreddit>[a-zA-Z0-9_]+)/ =~ params[:q]
    # https://imgur.com/r/aww
    # https://www.reddit.com/r/aww
    redirect Addressable::URI.new(path: "/imgur/r/#{subreddit}", query: params[:type]).normalize.to_s and return
  elsif /(?<username>[a-zA-Z0-9]+)\.imgur\.com/ =~ params[:q] && username != "i"
    # https://thebookofgray.imgur.com/
  elsif /imgur\.com\/(gallery\/)?(?<image_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/NdyrgaE
    # https://imgur.com/gallery/NdyrgaE
  elsif params[:q].start_with?("#")
    return [404, "This app does not support hashtags. Sorry."]
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
    response = Imgur.get("/account/#{username}")
    return [response.code, "Can't find a user with that name. Sorry. If you want a feed for a subreddit, enter \"r/#{username}\"."] if response.code == 404
    raise(ImgurError, response) if !response.success?
    user_id = response.json["data"]["id"]
    username = response.json["data"]["url"]
  end

  if user_id.nil?
    return [404, "This image was probably uploaded anonymously. Sorry."]
  else
    redirect Addressable::URI.new(path: "/imgur/#{user_id}/#{username}").normalize.to_s
  end
end

get "/imgur/:user_id/:username" do
  return [404, "Credentials not configured"] if !ENV["IMGUR_CLIENT_ID"]

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

  erb :"imgur.atom"
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
    redirect Addressable::URI.parse("https://www.svtplay.se/#{program}/atom.xml").normalize.to_s
  else
    return [404, "Could not find the program. Sorry."]
  end
end

get "/dilbert" do
  @feed = Feedjira.parse(HTTP.get("http://feeds.dilbert.com/DilbertDailyStrip").body)
  @entries = @feed.entries.map do |entry|
    data = $redis.get("dilbert:#{entry.id}")
    if data
      data = JSON.parse(data)
    else
      og = OpenGraph.new("https://dilbert.com/strip/#{entry.id}")
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
