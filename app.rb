# frozen_string_literal: true
# export RUBYOPT=--enable-frozen-string-literal

require "sinatra"
require "./config/application"
require "open-uri"

before do
  content_type :text
end

csrf_protection_enabled = ENV["CSRF_PROTECTION"] != "off"
$enabled_services = ENV["ENABLED_SERVICES"]&.split(",")

before %r{/(?:go|youtube|vimeo|instagram|soundcloud|mixcloud|twitch|speedrun|dailymotion|imgur|svtplay)} do
  if csrf_protection_enabled
    if !request.user_agent&.include?("Mozilla/") || !request.referer&.start_with?("#{request.base_url}/")
      halt [403, "This endpoint should not be used by a robot. RSS Box is open source so you should instead reimplement the thing you need in your own application.\n"]
    end
  end
  halt [400, "Insufficient parameters."] if params[:q].empty?
end

if $enabled_services
  before %r{/(youtube|vimeo|instagram|soundcloud|mixcloud|twitch|speedrun|dailymotion|imgur|svtplay).*} do
    if !$enabled_services.include?(params["captures"][0])
      halt [404, "Service not enabled."]
    end
  end
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
# javascript:location='https://rssbox.fly.dev/go?q='+encodeURIComponent(location.href);
# Or for Firefox:
# javascript:location='https://rssbox.fly.dev/?go='+encodeURIComponent(location.href);
get "/go" do
  if /^https?:\/\/(?:www\.|gaming\.)?youtu(?:\.be|be\.com)/ =~ params[:q]
    redirect Addressable::URI.new(path: "/youtube", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?instagram\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/instagram", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?soundcloud\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/soundcloud", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?mixcloud\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/mixcloud", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.|go\.)?twitch\.tv/ =~ params[:q]
    redirect Addressable::URI.new(path: "/twitch", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?speedrun\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/speedrun", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?dailymotion\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/dailymotion", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?vimeo\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/vimeo", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:[a-z0-9]+\.)?imgur\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/imgur", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/medium\.com\/(?<user>@?[^\/?&#]+)/ =~ params[:q]
    redirect Addressable::URI.parse("https://medium.com/feed/#{user}").normalize.to_s, 301
  elsif /^https?:\/\/dev\.to\/(?<user>[^\/?&#]+)/ =~ params[:q]
    redirect Addressable::URI.parse("https://dev.to/feed/#{user}").normalize.to_s, 301
  elsif /^https?:\/\/(?<name>[a-z0-9\-]+)\.blogspot\./ =~ params[:q]
    redirect Addressable::URI.parse("https://#{name}.blogspot.com/feeds/posts/default").normalize.to_s, 301
  elsif /^https?:\/\/groups\.google\.com\/(?:forum\/[^#]*#!(?:[a-z]+)|g)\/(?<name>[^\/?&#]+)/ =~ params[:q]
    # https://groups.google.com/forum/?oldui=1#!forum/rabbitmq-users
    # https://groups.google.com/forum/?oldui=1#!topic/rabbitmq-users/9D4BAuud6PU
    # https://groups.google.com/g/rabbitmq-users
    # https://groups.google.com/g/rabbitmq-users/c/9D4BAuud6PU
    redirect Addressable::URI.parse("https://groups.google.com/forum/feed/#{name}/msgs/atom.xml?num=50").normalize.to_s, 301
  elsif /^https?:\/\/www\.deviantart\.com\/(?<user>[^\/]+)/ =~ params[:q]
    redirect "https://backend.deviantart.com/rss.xml" + Addressable::URI.new(query: "type=deviation&q=by:#{user} sort:time").normalize.to_s, 301
  elsif /^(?<baseurl>https?:\/\/[a-zA-Z0-9\-]+\.tumblr\.com)/ =~ params[:q]
    redirect "#{baseurl}/rss", 301
  elsif /^https?:\/\/(?:itunes|podcasts)\.apple\.com\/.+\/id(?<id>\d+)/ =~ params[:q]
    # https://podcasts.apple.com/us/podcast/the-bernie-sanders-show/id1223800705
    response = App::HTTP.get("https://itunes.apple.com/lookup?id=#{id}")
    raise(App::HTTPError, response) if !response.success?
    redirect response.json["results"][0]["feedUrl"], 301
  elsif /^https?:\/\/(?:www\.)?svtplay\.se/ =~ params[:q]
    redirect Addressable::URI.new(path: "/svtplay", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?odysee\.com\/@(?<channelClaim>[^\/?#]+)/ =~ params[:q]
    # https://odysee.com/@eevblog:7
    redirect Addressable::URI.parse("https://odysee.com/$/rss/#{channelClaim}").normalize.to_s, 301
  else
    return [404, "Unknown service"]
  end
end

get %r{/twitter/(?<id>\d+)/(?<username>.+)} do
  return [410, "It's dead, Jim."]
end

get "/youtube" do
  return [404, "Credentials not configured"] if !ENV["GOOGLE_API_KEY"]

  if /youtube\.com\/channel\/(?<channel_id>(UC|S)[^\/?#]+)(?:\/search\?query=(?<query>[^&#]+))?/ =~ params[:q]
    # https://www.youtube.com/channel/UC4a-Gbdw7vOaccHmFo40b9g/videos
    # https://www.youtube.com/channel/SWu5RTwuNMv6U
    # https://www.youtube.com/channel/UCd6MoB9NC6uYN2grvUNT-Zg/search?query=aurora
  elsif /youtube\.com\/user\/(?<user>[^\/?#]+)(?:\/search\?query=(?<query>[^&#]+))?/ =~ params[:q]
    # https://www.youtube.com/user/khanacademy/videos
    # https://www.youtube.com/user/AmazonWebServices/search?query=aurora
  elsif /youtube\.com\/(?<path>c\/[^\/?#]+)(?:\/search\?query=(?<query>[^&#]+))?/ =~ params[:q]
    # https://www.youtube.com/c/khanacademy
    # https://www.youtube.com/c/khanacademy/search?query=Frequency+stability
    # there is no way to resolve these accurately through the API, the best way is to look for the channelId meta tag in the website HTML
    # note that slug != username, e.g. https://www.youtube.com/c/kawaiiguy and https://www.youtube.com/user/kawaiiguy are two different channels
  elsif /(?:youtu\.be|youtube\.com\/(?:embed|v|shorts))\/(?<video_id>[^?#]+)/ =~ params[:q]
    # https://youtu.be/vVXbgbMp0oY?t=1s
    # https://www.youtube.com/embed/vVXbgbMp0oY
    # https://www.youtube.com/v/vVXbgbMp0oY
    # https://www.youtube.com/shorts/QHEG3OB14GA
  elsif /youtube\.com\/clip\/(?<clip_id>[^?#]+)/ =~ params[:q]
    # https://www.youtube.com/clip/UgkxHm3PY3DSQt8ecB67IrP-stLw7LAmjZSe
  elsif /youtube\.com\/tv#\/watch\/video\/.*[?&]v=(?<video_id>[^&]+)/ =~ params[:q]
    # https://www.youtube.com/tv#/zylon-detail-surface?c=UCK5eBtuoj_HkdXKHNmBLAXg&resume
    # https://www.youtube.com/tv#/watch/video/idle?v=uYMD4elmVIE&resume
    # https://www.youtube.com/tv#/watch/video/control?v=uYMD4elmVIE&resume
    # https://www.youtube.com/tv#/watch/video/control?v=u6gsOQ8HZAU&list=PLTU3Sf6dSBnDnhfG6iCy41Pk6de7OHRZh&resume
  elsif /youtube\.com\/.*[?&]v=(?<video_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/watch?v=vVXbgbMp0oY&t=5s
  elsif /youtube\.com\/.*[?&]list=(?<playlist_id>[^&#]+)/ =~ params[:q]
    # https://www.youtube.com/playlist?list=PL0QrZvg7QIgpoLdNFnEePRrU-YJfr9Be7
  elsif /youtube\.com\/(?<handle>[^\/?#]+)/ =~ params[:q]
    # https://www.youtube.com/khanacademy
    # https://www.youtube.com/@awscommunity
  elsif /\b(?<channel_id>(?:UC[^\/?#]{22,}|S[^\/?#]{12,}))/ =~ params[:q]
    # it's a channel id
  elsif params[:q].start_with?("@")
    # it's a handle
    handle = params[:q]
  else
    # maybe it is a handle?
    handle = "@#{params[:q]}"
  end

  if playlist_id
    redirect "https://www.youtube.com/feeds/videos.xml" + Addressable::URI.new(query: "playlist_id=#{playlist_id}").normalize.to_s, 301
    return
  end

  if user
    channel_id, _ = App::Cache.cache("youtube.user", user.downcase, 60*60, 60) do
      response = App::YouTube.get("/channels", query: { forUsername: user })
      raise(App::GoogleError, response) if !response.success?
      if response.json["items"] && response.json["items"].length > 0
        response.json["items"][0]["id"]
      else
        "Error: Could not find the user. Please try with a video url instead."
      end
    end
  elsif handle
    channel_id, _ = App::Cache.cache("youtube.handle", handle.downcase, 60*60, 60) do
      response = App::YouTube.get("/channels", query: { forHandle: handle })
      raise(App::GoogleError, response) if !response.success?
      if response.json["items"] && response.json["items"].length > 0
        response.json["items"][0]["id"]
      else
        "Error: Could not find the user. Please try with a video url instead."
      end
    end
  elsif path
    channel_id, _ = App::Cache.cache("youtube.path", path.downcase, 60*60, 60) do
      response = App::HTTP.get("https://www.youtube.com/#{path}")
      if response.redirect?
        response = App::HTTP.get(response.redirect_url)
      end
      next "Error: Could not find the user. Please try with a video url instead." if response.code == 404
      raise(App::GoogleError, response) if !response.success?
      doc = Nokogiri::HTML(response.body)
      doc.at("meta[itemprop='identifier']")&.[]("content") || "Error: Could not find the user. Please try with a video url instead."
    end
  elsif video_id
    channel_id, _ = App::Cache.cache("youtube.video", video_id, 60*60, 60) do
      response = App::YouTube.get("/videos", query: { part: "snippet", id: video_id })
      raise(App::GoogleError, response) if !response.success?
      if response.json["items"].length > 0
        response.json["items"][0]["snippet"]["channelId"]
      end
    end
  elsif clip_id
    channel_id, _ = App::Cache.cache("youtube.clip", clip_id, 60*60, 60) do
      response = App::HTTP.get("https://www.youtube.com/clip/#{clip_id}")
      next "Error: Could not find the clip. Please try with a video url instead." if response.code == 404
      raise(App::GoogleError, response) if !response.success?
      doc = Nokogiri::HTML(response.body)
      doc.at("meta[itemprop='channelId']")&.[]("content") || "Error: Could not find the user. Please try with a video url instead."
    end
  end
  return [422, "Something went wrong. Try again later."] if channel_id.nil?
  return [422, channel_id] if channel_id.start_with?("Error:")

  if query || params.has_key?(:shift)
    username, _ = App::Cache.cache("youtube.channel", channel_id, 60*60, 60) do
      # it is no longer possible to get usernames using the API
      # note that the values include " - YouTube" at the end if the User-Agent is a browser
      og = OpenGraph.new("https://www.youtube.com/channel/#{channel_id}")
      username = og.url.split("/")[-1]
      username = og.title if username == channel_id
      username
    end
    return [422, "Something went wrong. Try again later."] if username.nil?
  end

  if query
    query = CGI.unescape(query) # youtube uses + here instead of %20
    redirect Addressable::URI.new(path: "/youtube/#{channel_id}/#{username}", query_values: { q: query }.merge(params.slice(:tz))).normalize.to_s, 301
  elsif channel_id
    if params.has_key?(:shift)
      redirect Addressable::URI.new(path: "/youtube/#{channel_id}/#{username}", query_values: params.slice(:tz)).normalize.to_s, 301
    else
      redirect "https://www.youtube.com/feeds/videos.xml" + Addressable::URI.new(query: "channel_id=#{channel_id}").normalize.to_s, 301
    end
  else
    return [404, "Could not find the channel."]
  end
end

get "/youtube/:channel_id/:username.ics" do |channel_id, username|
  return [404, "Credentials not configured"] if !ENV["GOOGLE_API_KEY"]

  @channel_id = channel_id
  @username = username
  @title = "#{username} on YouTube"

  data, _ = App::Cache.cache("youtube.ics", channel_id, 60*60, 60) do
    # The API is really inconsistent in listing scheduled live streams, but the RSS endpoint seems to consistently list them, so experiment with using that
    response = App::HTTP.get("https://www.youtube.com/feeds/videos.xml?channel_id=#{channel_id}")
    next "Error: This channel no longer exists or has no videos." if response.code == 404
    raise(App::GoogleError, response) if !response.success?
    doc = Nokogiri::XML(response.body)
    ids = doc.xpath("//yt:videoId").map(&:text)

    response = App::YouTube.get("/videos", query: { part: "snippet,liveStreamingDetails,contentDetails", id: ids.join(",") })
    raise(App::GoogleError, response) if !response.success?

    items = response.json["items"].sort_by! do |video|
      if video.has_key?("liveStreamingDetails")
        Time.parse(video["liveStreamingDetails"]["actualStartTime"] || video["liveStreamingDetails"]["scheduledStartTime"])
      else
        Time.parse(video["snippet"]["publishedAt"])
      end
    end.reverse!.map do |video|
      {
        "id" => video["id"],
        "title" => video["snippet"]["title"],
        "publishedAt" => video["snippet"]["publishedAt"],
        "duration" => video["contentDetails"]["duration"].parse_pt,
        "description" => video["snippet"]["description"],
        "liveStreamingDetails" => video["liveStreamingDetails"]&.slice("scheduledStartTime", "actualStartTime", "actualEndTime"),
      }.compact
    end.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  @data = JSON.parse(data)

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
    @data.select! { |v| v["title"].downcase.include?(q) }
  end

  erb :"youtube.ics"
end

get "/youtube/:channel_id/:username" do |channel_id, username|
  return [404, "Credentials not configured"] if !ENV["GOOGLE_API_KEY"]

  @channel_id = channel_id
  playlist_id = "UU" + channel_id[2..]
  @username = username
  if params.has_key?(:tz)
    if params[:tz].tz_offset?
      @tz = params[:tz]
    elsif TZInfo::Timezone.all_identifiers.include?(params[:tz])
      @tz = TZInfo::Timezone.get(params[:tz])
    end
  end

  data, @updated_at = App::Cache.cache("youtube.videos", channel_id, 60*60, 60) do
    # The results from this query are not sorted by publishedAt for whatever reason.. probably due to some uploads being scheduled to be published at a certain time
    response = App::YouTube.get("/playlistItems", query: { part: "snippet", playlistId: playlist_id, maxResults: 10 })
    next "Error: This channel no longer exists or has no videos." if response.code == 404
    raise(App::GoogleError, response) if !response.success?
    ids = response.json["items"].sort_by { |v| Time.parse(v["snippet"]["publishedAt"]) }.reverse.map { |v| v["snippet"]["resourceId"]["videoId"] }

    response = App::YouTube.get("/videos", query: { part: "snippet,liveStreamingDetails,contentDetails", id: ids.join(",") })
    raise(App::GoogleError, response) if !response.success?

    response.json["items"].map do |video|
      {
        "id" => video["id"],
        "title" => video["snippet"]["title"],
        "publishedAt" => video["snippet"]["publishedAt"],
        "duration" => video["contentDetails"]["duration"].parse_pt,
        "description" => video["snippet"]["description"],
        "liveStreamingDetails" => video["liveStreamingDetails"]&.slice("scheduledStartTime", "actualStartTime", "actualEndTime"),
      }.compact
    end.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  @data = JSON.parse(data)

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
    @data.select! { |v| v["title"].downcase.include?(q) }
    @title = "\"#{@query}\" from #{username}"
  else
    @title = "#{username} on YouTube"
  end

  if params.has_key?(:shorts)
    remove_shorts = (params[:shorts] == "0")
    @data.select! { |v| App::YouTube.is_short?(v["id"]) != remove_shorts }
  end

  if params.has_key?(:min_length) && min_length = params[:min_length].parse_duration
    @data.select! { |v| v["duration"] >= min_length }
  end

  @data.map do |video|
    video["description"].grep_urls
  end.flatten.tap { |urls| App::URL.resolve(urls) }

  erb :"youtube.atom"
end

get %r{/googleplus/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [410, "RIP Google+ 2011-2019"]
end

get "/vimeo" do
  if /vimeo\.com\/user(?<user_id>\d+)/ =~ params[:q]
    # https://vimeo.com/user7103699
  elsif /vimeo\.com\/ondemand\/(?<user>[^\/?&#]+)/ =~ params[:q]
    # https://vimeo.com/ondemand/thealphaquadrant/
    response = App::Vimeo.get("/ondemand/pages/#{user}")
    return [404, "Could not find the user."] if response.code == 404
    raise(App::VimeoError, response) if !response.success?
    user_id = response.json["user"]["uri"][/\d+/]
  elsif /vimeo\.com\/(?<video_id>\d+)(\?|#|$)/ =~ params[:q]
    # https://vimeo.com/155672086
    response = App::Vimeo.get("/videos/#{video_id}")
    return [404, "Could not find the video."] if response.code == 404
    raise(App::VimeoError, response) if !response.success?
    user_id = response.json["user"]["uri"][/\d+/]
  elsif /vimeo\.com\/(?:channels\/)?(?<user>[^\/?&#]+)/ =~ params[:q] || user = params[:q]
    # it's probably a channel name
    response = App::Vimeo.get("/users", query: { query: user })
    return [404, "Could not find the channel."] if response.code == 404
    raise(App::VimeoError, response) if !response.success?
    if response.json["data"].length > 0
      user_id = response.json["data"][0]["uri"].gsub("/users/","").to_i
    end
  end

  if user_id
    redirect "https://vimeo.com/user#{user_id}/videos/rss", 301
  else
    return [404, "Could not find the channel."]
  end
end

get %r{/facebook/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [410, "Facebook functionality has been removed since I do not have API access. Maybe we can rebuild it some day, but using scraping techniques or something."]
end

get "/instagram" do
  if /instagram\.com\/(?:p|tv)\/(?<post_id>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/p/B-Pv6COFOjV/
    # https://www.instagram.com/tv/B-Pv6COFOjV/
    # https://www.instagram.com/p/CZfn8_-uYDz/ (carousel with video and photos)
  elsif params[:q].include?("instagram.com/explore/") || params[:q].start_with?("#")
    return [404, "This app does not support hashtags."]
  elsif /instagram\.com\/(?<name>[^\/?#]+)/ =~ params[:q]
    # https://www.instagram.com/infectedmushroom/
  else
    name = params[:q][/[^\/?#]+/]
  end

  if post_id
    post = App::Instagram.get_post(post_id)
    return [422, "Something went wrong. Try again later."] if post.nil?
    user = post["owner"]
    path = "#{user["id"]}/#{user["username"]}"
  else
    path, _ = App::Cache.cache("instagram.user", name.downcase, 24*60*60, 60*60) do
      response = App::Instagram.get("/#{name}/")
      if response.success?
        user = response.json["graphql"]["user"]
      else
        # https://www.instagram.com/web/search/topsearch/?query=infected
        response = App::Instagram.get("/web/search/topsearch/", query: { query: name })
        raise(App::InstagramError, response) if !response.success?
        user = response.json["users"][0]["user"]
      end
      "#{user["id"] || user["pk"]}/#{user["username"]}"
    rescue App::InstagramRatelimitError
      "ratelimited"
    end
    return [422, "Something went wrong. Try again later."] if path.nil?
    return [422, path] if path.start_with?("Error:")
    return [429, "Error: Instagram is ratelimited. For more information, see https://github.com/stefansundin/rssbox/issues/39"] if path == "ratelimited"
  end
  redirect Addressable::URI.new(path: "/instagram/#{path}").normalize.to_s, 301
end

get "/instagram/download" do
  return [400, "Insufficient parameters"] if params[:url].empty?

  if /instagram\.com\/(?:p|tv)\/(?<post_id>[^\/?#]+)/ =~ params[:url]
    # https://www.instagram.com/p/B-Pv6COFOjV/
    # https://www.instagram.com/tv/B-Pv6COFOjV/
  else
    post_id = params[:url]
  end

  post = App::Instagram.get_post(post_id)
  return [422, "Something went wrong. Try again later."] if post.nil?

  if env["HTTP_ACCEPT"] == "application/json"
    content_type :json
    created_at = Time.at(post["taken_at_timestamp"])
    caption = post["text"] rescue post_id

    return post["nodes"].map.with_index do |node, i|
      url = node["video_url"] || node["display_url"]
      filename = "#{created_at.to_date} - #{post["owner"]["username"]} - #{caption}"
      filename += " - #{i+1}" if post["nodes"].length > 1
      filename += "#{url.url_ext}"
      {
        url: url,
        filename: filename.to_filename,
      }
    end.to_json
  end

  node = post["nodes"][0]
  url = node["video_url"] || node["display_url"]
  return [422, "Something went wrong. Try again later."] if !url
  redirect url
end

get %r{/instagram/(?<user_id>\d+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id
  @user = CGI.unescape(username)

  data, @updated_at = App::Cache.cache("instagram.posts", user_id, 4*60*60, 60*60) do
    # To find the query_hash, simply use the Instagram website and monitor the network calls.
    # This request in particular is the one that gets the next page when you scroll down on a profile, but we change it to get the first 12 posts instead of the second or third page.
    response = App::Instagram.get("/graphql/query/", {
      query: { query_hash: "f045d723b6f7f8cc299d62b57abd500a", variables: "{\"id\":\"#{user_id}\",\"first\":12}" },
    })
    raise(App::InstagramError, response) if !response.success? || !response.json?
    user = response.json["data"]["user"]
    next "Error: Instagram user does not exist." if !user

    user["edge_owner_to_timeline_media"]["edges"].map do |post|
      if post["node"]["__typename"] == "GraphSidecar"
        nodes = App::Instagram.get_post(post["node"]["shortcode"])["nodes"]
      else
        nodes = [ post["node"].slice("is_video", "display_url", "video_url") ]
      end
      text = post["node"]["edge_media_to_caption"]["edges"][0]["node"]["text"] if post["node"]["edge_media_to_caption"]["edges"][0]

      {
        "id" => post["node"]["id"],
        "shortcode" => post["node"]["shortcode"],
        "taken_at_timestamp" => post["node"]["taken_at_timestamp"],
        "username" => post["node"]["owner"]["username"],
        "text" => text,
        "nodes" => nodes,
      }
    end.to_json
  rescue App::InstagramRatelimitError
    "ratelimited"
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  if data == "ratelimited"
    if Time.now < @updated_at+300
      # To make it easier to subscribe to Instagram feeds, there is a grace period for 5 minutes where an empty feed is returned.
      # Note that you have to manually construct the feed URL yourself.
      data = "[]"
    else
      return [429, "Error: Instagram is ratelimited. For more information, see https://github.com/stefansundin/rssbox/issues/39"]
    end
  end

  @data = JSON.parse(data)

  type = %w[videos photos].pick(params[:type]) || "posts"
  if type == "videos"
    @data.select! { |post| post["nodes"].any? { |node| node["is_video"] } }
  elsif type == "photos"
    @data.select! { |post| !post["nodes"].any? { |node| node["is_video"] } }
  end

  @title = @user
  @title += "'s #{type}" if type != "posts"
  @title += " on Instagram"

  @data.select do |post|
    post["text"]
  end.map do |post|
    post["text"].grep_urls
  end.flatten.tap { |urls| App::URL.resolve(urls) }

  erb :"instagram.atom"
end

get "/soundcloud" do
  return [404, "Credentials not configured"] if !ENV["SOUNDCLOUD_CLIENT_ID"] || !ENV["SOUNDCLOUD_CLIENT_SECRET"]

  if /soundcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://soundcloud.com/infectedmushroom/01-she-zorement?in=infectedmushroom/sets/converting-vegetarians-ii
  else
    username = params[:q][/[^\/?&#]+/]
    return [400, "Invalid parameter."] if username.empty?
  end

  path, _ = App::Cache.cache("soundcloud.user", username.downcase, 60*60, 60) do
    response = App::Soundcloud.get("/resolve", query: { url: "https://soundcloud.com/#{username}" })
    if response.code == 302
      api_url = response.headers["location"][0]
      next "Error: Can't resolve the user." if !api_url.include?("soundcloud.com/users/")
      user_id = api_url.split("/").last
    elsif response.code == 404 && username.numeric?
      user_id = username
    elsif response.code == 404
      next "Error: Can't find a user with that name."
    else
      raise(App::SoundcloudError, response)
    end

    response = App::Soundcloud.get("/users/#{user_id}")
    raise(App::SoundcloudError, response) if !response.success?
    data = response.json

    "#{data["id"]}/#{data["permalink"]}"
  end
  return [422, "Something went wrong. Try again later."] if path.nil?
  return [422, path] if path.start_with?("Error:")

  redirect Addressable::URI.new(path: "/soundcloud/#{path}").normalize.to_s, 301
end

get "/soundcloud/download" do
  return [404, "Credentials not configured"] if !ENV["SOUNDCLOUD_CLIENT_ID"] || !ENV["SOUNDCLOUD_CLIENT_SECRET"]

  url = params[:url]
  return [404, "Please use a URL directly to a track."] if !url.start_with?("https://soundcloud.com/")
  response = App::Soundcloud.get("/resolve", query: { url: url })
  return [response.code, "URL does not resolve."] if response.code == 404
  raise(App::SoundcloudError, response) if response.code != 302

  api_url = response.headers["location"][0]
  return [404, "URL does not resolve to a track."] if !api_url.include?("soundcloud.com/tracks/")

  track_id = api_url.split("/").last
  response = App::Soundcloud.get("/tracks/#{track_id}/stream")
  return [response.code, "Does not seem like this track is downloadable."] if response.code != 302

  stream_url = response.headers["location"][0]

  if env["HTTP_ACCEPT"] == "application/json"
    response = App::Soundcloud.get("/tracks/#{track_id}")
    data = response.json
    filename = "#{Date.parse(data["created_at"])} - #{data["user"]["username"]} - #{data["title"]}.mp3"

    content_type :json
    return [{
      url: stream_url,
      filename: filename.to_filename,
    }].to_json
  end

  redirect stream_url, 302
end

get %r{/soundcloud/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [404, "Credentials not configured"] if !ENV["SOUNDCLOUD_CLIENT_ID"] || !ENV["SOUNDCLOUD_CLIENT_SECRET"]

  @id = id

  data, @updated_at = App::Cache.cache("soundcloud.tracks", id, 4*60*60, 60) do
    response = App::Soundcloud.get("/users/#{id}/tracks")
    next "Error: That user no longer exist." if response.code == 500 && response.body == '{"error":"Match failed"}'
    raise(App::SoundcloudError, response) if !response.success?

    data = response.json
    if data.length > 0
      user = data[0]["user"]["username"]
      user_permalink = data[0]["user"]["permalink"]
    end
    tracks = data.map do |track|
      {
        "id" => track["id"],
        "created_at" => track["created_at"],
        "title" => track["title"],
        "description" => track["description"],
        "duration" => (track["duration"] / 1000),
        "artwork_url" => track["artwork_url"],
        "permalink_url" => track["permalink_url"],
      }
    end

    {
      "user" => user,
      "username" => user_permalink,
      "tracks" => tracks,
    }.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  @data = JSON.parse(data)
  @user = @data["user"] || CGI.unescape(username)
  @username = @data["username"] || CGI.unescape(username)

  @data["tracks"].map do |track|
    track["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| App::URL.resolve(urls) }

  erb :"soundcloud.atom"
end

get "/mixcloud" do
  if /mixcloud\.com\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.mixcloud.com/infected-live/infected-mushroom-liveedc-las-vegas-21-5-2014/
  else
    username = params[:q][/[^\/?&#]+/]
    return [400, "Invalid parameter."] if username.empty?
  end

  path, _ = App::Cache.cache("mixcloud.user", username.downcase, 24*60*60, 60) do
    response = App::Mixcloud.get("/#{username}/")
    next "Error: Can't find a user with that name." if response.code == 404
    next "Error: Please enter a valid username." if response.code == 400
    raise(App::MixcloudError, response) if !response.success?
    data = response.json
    "#{data["username"]}/#{data["name"]}"
  end
  return [422, "Something went wrong. Try again later."] if path.nil?
  return [422, path] if path.start_with?("Error:")

  redirect Addressable::URI.new(path: "/mixcloud/#{path}").normalize.to_s, 301
end

get %r{/mixcloud/(?<username>[^/]+)/(?<user>.+)} do |username, user|
  data, @updated_at = App::Cache.cache("mixcloud.tracks", username.downcase, 4*60*60, 60) do
    response = App::Mixcloud.get("/#{username}/cloudcasts/")
    next "Error: That username no longer exist." if response.code == 404
    raise(App::MixcloudError, response) if !response.success?
    response.json["data"].map do |track|
      {
        "audio_length" => track["audio_length"],
        "created_time" => track["created_time"],
        "name" => track["name"],
        "pictures" => track["pictures"].slice("extra_large", "medium"),
        "slug" => track["slug"],
        "url" => track["url"],
        "user" => track["user"].slice("username", "name"),
      }
    end.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  @data = JSON.parse(data)
  @username = @data[0]["user"]["username"] rescue CGI.unescape(username)
  @user = @data[0]["user"]["name"] rescue CGI.unescape(user)

  erb :"mixcloud.atom"
end

get "/twitch" do
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

  if /twitch\.tv\/directory\/game\/(?<game_name>[^\/?#]+)/ =~ params[:q]
    # https://www.twitch.tv/directory/game/Perfect%20Dark
    game_name = Addressable::URI.unescape(game_name)
  elsif /twitch\.tv\/directory/ =~ params[:q]
    # https://www.twitch.tv/directory/all/tags/7cefbf30-4c3e-4aa7-99cd-70aabb662f27
    return [404, "Unsupported url."]
  elsif /twitch\.tv\/videos\/(?<vod_id>\d+)/ =~ params[:q]
    # https://www.twitch.tv/videos/25133028
  elsif /twitch\.tv\/(?<username>[^\/?#]+)/ =~ params[:q]
    # https://www.twitch.tv/majinphil
    # https://www.twitch.tv/gsl/video/25133028 (legacy url)
  else
    username = params[:q][/[^\/?&#]+/]
    return [400, "Invalid parameter."] if username.empty?
  end

  if game_name
    path, _ = App::Cache.cache("twitch.game", game_name.downcase, 60*60, 60) do
      response = App::Twitch.get("/games", query: { name: game_name })
      raise(App::TwitchError, response) if !response.success?
      data = response.json["data"][0]
      next "Error: Can't find a game with that name." if data.nil?
      "#{data["id"]}/#{game_name}"
    end
    return [422, "Something went wrong. Try again later."] if path.nil?
    return [422, path] if path.start_with?("Error:")
    redirect Addressable::URI.new(path: "/twitch/directory/game/#{path}").normalize.to_s, 301
  elsif vod_id
    path, _ = App::Cache.cache("twitch.vod", vod_id, 60*60, 60) do
      response = App::Twitch.get("/videos", query: { id: vod_id })
      next "Error: Video does not exist." if response.code == 404
      raise(App::TwitchError, response) if !response.success?
      data = response.json["data"][0]
      "#{data["user_id"]}/#{data["user_login"]}"
    end
    return [422, "Something went wrong. Try again later."] if path.nil?
    return [422, path] if path.start_with?("Error:")
    redirect Addressable::URI.new(path: "/twitch/#{path}").normalize.to_s, 301
  else
    path, _ = App::Cache.cache("twitch.user", username.downcase, 60*60, 60) do
      response = App::Twitch.get("/users", query: { login: username })
      next "Error: The username contains invalid characters." if response.code == 400
      raise(App::TwitchError, response) if !response.success?
      data = response.json["data"][0]
      next "Error: Can't find a user with that name." if data.nil?
      "#{data["id"]}/#{data["login"]}"
    end
    return [422, "Something went wrong. Try again later."] if path.nil?
    return [422, path] if path.start_with?("Error:")
    redirect Addressable::URI.new(path: "/twitch/#{path}").normalize.to_s, 301
  end
end

get "/twitch/download" do
  return [404, "Credentials not configured"] if !ENV["TWITCHTOKEN_CLIENT_ID"]
  return [400, "Insufficient parameters"] if params[:url].empty?

  if /twitch\.tv\/[^\/]+\/clip\/(?<clip_slug>[^?&#]+)/ =~ params[:url] || /clips\.twitch\.tv\/(?:embed\?clip=)?(?<clip_slug>[^?&#]+)/ =~ params[:url]
    # https://www.twitch.tv/majinphil/clip/TenaciousCreativePieNotATK
    # https://clips.twitch.tv/DignifiedThirstyDogYee
    # https://clips.twitch.tv/majinphil/UnusualClamRaccAttack (deprecated url)
    # https://clips.twitch.tv/embed?clip=DignifiedThirstyDogYee&autoplay=false&parent=example.com
  elsif /twitch\.tv\/(?:[^\/]+\/)?(?:v|videos?)\/(?<vod_id>\d+)/ =~ params[:url] || /(?:^|v)(?<vod_id>\d+)/ =~ params[:url]
    # https://www.twitch.tv/videos/25133028
    # https://www.twitch.tv/gsl/video/25133028 (legacy url)
    # https://www.twitch.tv/gamesdonequick/video/34377308?t=53m40s (legacy url)
    # https://www.twitch.tv/gamesdonequick/v/34377308?t=53m40s (legacy url)
    # https://player.twitch.tv/?video=v103620362 ("v" is optional)
  elsif /twitch\.tv\/(?<channel_name>[^\/?#]+)/ =~ params[:url]
    # https://www.twitch.tv/trevperson
  else
    channel_name = params[:url][/[^\/?&#]+/]
    return [400, "Invalid parameter."] if channel_name.empty?
  end

  if clip_slug
    response = App::HTTP.get("https://clips.twitch.tv/api/v2/clips/#{clip_slug}/status")
    return [response.code, "Clip does not seem to exist."] if response.code == 404
    raise(App::TwitchError, response) if !response.success?
    url = response.json["quality_options"][0]["source"]
    return [404, "Can't find clip."] if url.nil?
    redirect url
    return
  elsif vod_id
    response = App::Twitch.get("/videos", query: { id: vod_id })
    return [response.code, "Video does not exist."] if response.code == 404
    raise(App::TwitchError, response) if !response.success?
    data = response.json["data"][0]

    response = App::TwitchToken.get("/vods/#{vod_id}/access_token")
    raise(App::TwitchError, response) if !response.success?
    vod_data = response.json

    url = "http://usher.twitch.tv" + Addressable::URI.new(path: "/vod/#{vod_id}", query: "nauthsig=#{vod_data["sig"]}&nauth=#{vod_data["token"]}").normalize.to_s
    fn = "#{Date.parse(data["created_at"])} - #{data["user_name"]} - #{data["title"]}.mp4".to_filename
  elsif channel_name
    response = App::TwitchToken.get("/channels/#{channel_name}/access_token")
    return [response.code, "Channel does not seem to exist."] if response.code == 404
    raise(App::TwitchError, response) if !response.success?

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
    # https://clips.twitch.tv/embed?clip=DignifiedThirstyDogYee&autoplay=false&parent=example.com
  elsif /twitch\.tv\/(?:[^\/]+\/)?(?:v|videos?)\/(?<vod_id>\d+)/ =~ params[:url] || /(?:^|v)(?<vod_id>\d+)/ =~ params[:url]
    # https://www.twitch.tv/videos/25133028
    # https://www.twitch.tv/gsl/video/25133028 (legacy url)
    # https://www.twitch.tv/gamesdonequick/video/34377308?t=53m40s (legacy url)
    # https://www.twitch.tv/gamesdonequick/v/34377308?t=53m40s (legacy url)
    # https://player.twitch.tv/?video=v103620362 ("v" is optional)
  elsif /twitch\.tv\/(?<channel_name>[^\/?#]+)/ =~ params[:url]
    # https://www.twitch.tv/trevperson
  else
    channel_name = params[:url][/[^\/?&#]+/]
    return [400, "Invalid parameter."] if channel_name.empty?
  end

  if clip_slug
    response = App::HTTP.get("https://clips.twitch.tv/api/v2/clips/#{clip_slug}/status")
    return [response.code, "Clip does not seem to exist."] if response.code == 404
    raise(App::TwitchError, response) if !response.success?
    streams = response.json["quality_options"].map { |s| s["source"] }
    return [404, "Can't find clip."] if streams.empty?
  elsif vod_id
    response = App::TwitchToken.get("/vods/#{vod_id}/access_token")
    return [response.code, "Video does not exist."] if response.code == 404
    raise(App::TwitchError, response) if !response.success?
    data = response.json
    playlist_url = "http://usher.twitch.tv" + Addressable::URI.new(path: "/vod/#{vod_id}", query: "nauthsig=#{data["sig"]}&nauth=#{data["token"]}").normalize.to_s

    response = App::HTTP.get(playlist_url)
    return [response.code, "Video does not exist."] if response.code == 404
    return [response.code, "This video is restricted to subscribers."] if response.code == 403 && response.json[0]["error_code"] == "vod_manifest_restricted"
    raise(App::TwitchError, response) if !response.success?
    streams = response.body.split("\n").reject { |line| line[0] == "#" } + [playlist_url]
  elsif channel_name
    response = App::TwitchToken.get("/channels/#{channel_name}/access_token")
    return [response.code, "Channel does not seem to exist."] if response.code == 404
    raise(App::TwitchError, response) if !response.success?

    data = response.json
    token_data = JSON.parse(data["token"])
    playlist_url = "http://usher.ttvnw.net" + Addressable::URI.new(path: "/api/channel/hls/#{token_data["channel"]}.m3u8", query: "token=#{data["token"]}&sig=#{data["sig"]}&allow_source=true&allow_spectre=true").normalize.to_s

    response = App::HTTP.get(playlist_url)
    return [response.code, "Channel does not seem to be online."] if response.code == 404
    raise(App::TwitchError, response) if !response.success?
    streams = response.body.split("\n").reject { |line| line.start_with?("#") } + [playlist_url]
  end
  if request.user_agent&.include?("Mozilla/")
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

  data, @updated_at = App::Cache.cache("twitch.videos.game", "#{id}.#{type}", 60*60, 60) do
    response = App::Twitch.get("/videos", query: { game_id: id, type: type })
    raise(App::TwitchError, response) if !response.success?

    videos = response.json["data"].reject do |video|
      # live broadcasts show up here too, and the simplest way of filtering them out seems to be to see if thumbnail_url is populated or not
      video["thumbnail_url"].empty?
    end.map do |video|
      {
        "created_at" => video["created_at"],
        "description" => video["description"].strip,
        "duration" => video["duration"].parse_duration,
        "id" => video["id"],
        "title" => video["title"].strip,
        "type" => video["type"],
        "user_name" => video["user_name"],
      }
    end

    {
      "videos" => videos,
    }.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?

  @data = JSON.parse(data)
  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/directory/game/#{game_name}").normalize.to_s

  @title = game_name
  @title += " highlights" if type == "highlight"
  @title += " on Twitch"

  @data["videos"].map do |video|
    video["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| App::URL.resolve(urls) }

  erb :"twitch.atom"
end

get %r{/twitch/(?<id>\d+)/(?<user>.+)\.ics} do |id, user|
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

  type = %w[all upload archive highlight].pick(params[:type]) || "all"

  data, @updated_at = App::Cache.cache("twitch.videos.user", "#{id}.#{type}", 60*60, 60) do
    response = App::Twitch.get("/videos", query: { user_id: id, type: type })
    raise(App::TwitchError, response) if !response.success?

    data = response.json["data"]
    user_name = data[0]["user_name"] if data.length > 0
    user_login = data[0]["user_login"] if data.length > 0
    videos = data.map do |video|
      {
        "id" => video["id"],
        "created_at" => video["created_at"],
        "published_at" => video["published_at"],
        "is_live" => video["thumbnail_url"].empty?,
        "type" => video["type"],
        "title" => video["title"].strip,
        "description" => video["description"].strip,
        "duration" => video["duration"].parse_duration,
      }
    end

    {
      "user_name" => user_name,
      "user_login" => user_login,
      "videos" => videos,
    }.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?

  @data = JSON.parse(data)
  user_name = @data["user_name"] || CGI.unescape(user)
  user_login = @data["user_login"] || CGI.unescape(user)
  @title = "#{user_name} on Twitch"
  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/#{user_login.downcase}").normalize.to_s

  erb :"twitch.ics"
end

get %r{/twitch/(?<id>\d+)/(?<user>.+)} do |id, user|
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

  @id = id
  @type = "user"
  type = %w[all upload archive highlight].pick(params[:type]) || "all"

  data, @updated_at = App::Cache.cache("twitch.videos.user", "#{id}.#{type}", 60*60, 60) do
    response = App::Twitch.get("/videos", query: { user_id: id, type: type })
    raise(App::TwitchError, response) if !response.success?

    data = response.json["data"]
    user_name = data[0]["user_name"] if data.length > 0
    user_login = data[0]["user_login"] if data.length > 0
    videos = data.map do |video|
      {
        "id" => video["id"],
        "created_at" => video["created_at"],
        "published_at" => video["published_at"],
        "is_live" => video["thumbnail_url"].empty?,
        "type" => video["type"],
        "title" => video["title"].strip,
        "description" => video["description"].strip,
        "duration" => video["duration"].parse_duration,
      }
    end

    {
      "user_name" => user_name,
      "user_login" => user_login,
      "videos" => videos,
    }.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?

  @data = JSON.parse(data)
  @user_name = @data["user_name"] || CGI.unescape(user)
  @user_login = @data["user_login"] || CGI.unescape(user)
  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/#{@user_login.downcase}").normalize.to_s
  @data["videos"].reject! { |v| v["is_live"] }

  @title = @user_name
  @title += "'s highlights" if type == "highlight"
  @title += " on Twitch"

  @data["videos"].map do |video|
    video["description"]
  end.compact.map(&:grep_urls).flatten.tap { |urls| App::URL.resolve(urls) }

  erb :"twitch.atom"
end

get "/speedrun" do
  if /speedrun\.com\/run\/(?<run_id>[^\/?#]+)/ =~ params[:q]
    # https://www.speedrun.com/run/1zx0qkez
    game, _ = App::Cache.cache("speedrun.run", run_id, 60*60, 60) do
      response = App::Speedrun.get("/runs/#{run_id}")
      raise(App::SpeedrunError, response) if !response.success?
      response.json["data"]["game"]
    end
    return [422, "Something went wrong. Try again later."] if game.nil?
  elsif /speedrun\.com\/(?<game>[^\/?#]+)/ =~ params[:q]
    # https://www.speedrun.com/alttp#No_Major_Glitches
  else
    game = params[:q]
  end

  path, _ = App::Cache.cache("speedrun.game", game.downcase, 60*60, 60) do
    response = App::Speedrun.get("/games/#{game}")
    if response.redirect?
      game = response.headers["location"][0].split("/")[-1]
      response = App::Speedrun.get("/games/#{game}")
    end
    next "Error: Can't find a game with that name." if response.code == 404
    raise(App::SpeedrunError, response) if !response.success?
    data = response.json["data"]
    "#{data["id"]}/#{data["abbreviation"]}"
  end
  return [422, "Something went wrong. Try again later."] if path.nil?
  return [422, path] if path.start_with?("Error:")

  redirect Addressable::URI.new(path: "/speedrun/#{path}").normalize.to_s, 301
end

get "/speedrun/:id/:abbr" do |id, abbr|
  @id = id
  @abbr = abbr

  data, @updated_at = App::Cache.cache("speedrun.runs", id, 60*60, 60) do
    response = App::Speedrun.get("/runs", query: { status: "verified", orderby: "verify-date", direction: "desc", game: id, embed: "category,players,level,platform,region" })
    raise(App::SpeedrunError, response) if !response.success?
    response.json["data"].reject do |run|
      run["videos"].nil?
    end.map do |run|
      players = run["players"]["data"].map { |player| player["name"] || player["names"]["international"] }
      videos = if run["videos"].has_key?("links")
        run["videos"]["links"].map { |link| link["uri"] }
      elsif run["videos"].has_key?("text")
        [ run["videos"]["text"] ]
      end

      if !run["level"]["data"].empty?
        category_link = "https://www.speedrun.com/#{@abbr}/#{run["level"]["data"]["weblink"].split("/")[-1]}"
        category = "#{run["category"]["data"]["name"]}: #{run["level"]["data"]["name"]}"
      else
        category_link = "https://www.speedrun.com/#{@abbr}##{run["category"]["data"]["weblink"].partition("#")[2]}"
        category = run["category"]["data"]["name"]
      end

      if run["platform"]["data"].is_a?(Hash)
        platform = run["platform"]["data"]["name"]
        platform += " (#{run["region"]["data"]["name"]})" if run["system"]["region"]
        platform += " [emu]" if run["system"]["emulated"]
      end

      {
        "id" => run["id"],
        "date" => run["date"],
        "submitted" => run["submitted"],
        "comment" => run["comment"],
        "times" => run["times"]["primary_t"].round,
        "category_link" => category_link,
        "category" => category,
        "platform" => platform,
        "players" => players,
        "videos" => videos,
      }
    end.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  @data = JSON.parse(data)

  @data.map do |run|
    [
      run["videos"],
      run["comment"],
    ].flatten.compact.map(&:grep_urls)
  end.flatten.tap { |urls| App::URL.resolve(urls) }

  erb :"speedrun.atom"
end

get %r{/ustream/(?<id>\d+)/(?<title>.+)} do |id, title|
  return [410, "RIP Ustream"]
end

get "/dailymotion" do
  if /dailymotion\.com\/video\/(?<video_id>[a-zA-Z0-9]+)/ =~ params[:q] || /dai\.ly\/(?<video_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://www.dailymotion.com/video/x3r4xy2
    # https://www.dailymotion.com/video/k1ZotianZxwzm6fmny2
    # https://dai.ly/x3r3q7b?start=60
  elsif /dailymotion\.com\/playlist\/(?<playlist_id>[a-z0-9]+)/ =~ params[:q]
    # https://www.dailymotion.com/playlist/x52z5h
  elsif /dailymotion\.com\/(?<user>[^\/?#]+)/ =~ params[:q]
    # https://www.dailymotion.com/ParodyEdits/playlists
    # https://www.dailymotion.com/ParodyEdits/videos
    # https://www.dailymotion.com/ParodyEdits
  else
    # it's probably a username
    user = params[:q][/[^\/?&#]+/]
    return [400, "Invalid parameter."] if user.empty?
  end

  if video_id
    user, _ = App::Cache.cache("dailymotion.video", video_id, 60*60, 60) do
      response = App::Dailymotion.get("/video/#{video_id}")
      next "Error: Can't find a video with that ID." if response.code == 404
      raise(App::DailymotionError, response) if !response.success?
      response.json["owner"]
    end
  elsif playlist_id
    user, _ = App::Cache.cache("dailymotion.playlist", playlist_id, 60*60, 60) do
      response = App::Dailymotion.get("/playlist/#{playlist_id}")
      next "Error: Can't find a playlist with that ID." if response.code == 404
      raise(App::DailymotionError, response) if !response.success?
      response.json["owner"]
    end
  end
  return [404, user] if user.start_with?("Error:")
  return [422, "Something went wrong. Try again later."] if user.nil?

  path, _ = App::Cache.cache("dailymotion.user", user.downcase, 60*60, 60) do
    response = App::Dailymotion.get("/user/#{user}", query: { fields: "id,username" })
    next "Error: Can't find a user with that name." if response.code == 404
    raise(App::DailymotionError, response) if !response.success?
    data = response.json
    "#{data["id"]}/#{data["username"]}"
  end
  return [404, path] if path.start_with?("Error:")

  redirect Addressable::URI.new(path: "/dailymotion/#{path}").normalize.to_s, 301
end

get %r{/dailymotion/(?<user_id>[a-z0-9]+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id
  @username = CGI.unescape(username)

  data, @updated_at = App::Cache.cache("dailymotion.videos", user_id, 60*60, 60) do
    response = App::Dailymotion.get("/user/#{user_id}/videos", query: { fields: "id,title,created_time,description,allow_embed,available_formats,duration" })
    next "Error: That user no longer exist." if response.code == 404
    raise(App::DailymotionError, response) if !response.success?
    response.json["list"].map do |video|
      video.slice("id", "title", "created_time", "duration", "title", "description")
    end.to_json
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  @data = JSON.parse(data)

  erb :"dailymotion.atom"
end

get "/imgur" do
  return [404, "Credentials not configured"] if !ENV["IMGUR_CLIENT_ID"]

  if /imgur\.com\/user\/(?<username>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/user/thebookofgray
  elsif /imgur\.com\/a\/(?<album_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/a/IwyIm
  elsif /(?:^\/?r\/|(?:imgur|reddit)\.com\/r\/)(?<subreddit>[a-zA-Z0-9_]+)/ =~ params[:q]
    # https://imgur.com/r/aww
    # https://www.reddit.com/r/aww
    redirect Addressable::URI.new(path: "/imgur/r/#{subreddit}", query: params[:type]).normalize.to_s, 301
    return
  elsif /(?<username>[a-zA-Z0-9]+)\.imgur\.com/ =~ params[:q] && username != "i"
    # https://thebookofgray.imgur.com/
  elsif /imgur\.com\/(gallery\/)?(?<image_id>[a-zA-Z0-9]+)/ =~ params[:q]
    # https://imgur.com/NdyrgaE
    # https://imgur.com/gallery/NdyrgaE
  elsif params[:q].start_with?("#")
    return [404, "This app does not support hashtags."]
  else
    # it's probably a username
    username = params[:q]
  end

  if image_id
    path, _ = App::Cache.cache("imgur.image", image_id, 60*60, 60) do
      response = App::Imgur.get("/gallery/album/#{image_id}")
      response = App::Imgur.get("/gallery/image/#{image_id}") if !response.success?
      response = App::Imgur.get("/image/#{image_id}") if !response.success?
      next "Error: Can't identify #{image_id} as an image or gallery." if response.code == 404
      raise(App::ImgurError, response) if !response.success?
      data = response.json["data"]
      next "Error: This image was uploaded anonymously." if data["account_id"].nil?
      "#{data["account_id"]}/#{data["account_url"]}"
    end
  elsif album_id
    path, _ = App::Cache.cache("imgur.album", album_id, 60*60, 60) do
      response = App::Imgur.get("/album/#{album_id}")
      next "Error: Can't identify #{album_id} as an album." if response.code == 404
      raise(App::ImgurError, response) if !response.success?
      data = response.json["data"]
      "#{data["account_id"]}/#{data["account_url"]}"
    end
  elsif username
    path, _ = App::Cache.cache("imgur.account", username.downcase, 60*60, 60) do
      response = App::Imgur.get("/account/#{username}")
      next "Error: Can't find a user with that name. If you want a feed for a subreddit, enter \"r/#{username}\"." if response.code == 404
      raise(App::ImgurError, response) if !response.success?
      data = response.json["data"]
      "#{data["id"]}/#{data["url"]}"
    end
  end
  return [422, "Something went wrong. Try again later."] if path.nil?
  return [422, path] if path.start_with?("Error:")

  redirect Addressable::URI.new(path: "/imgur/#{path}").normalize.to_s, 301
end

get "/imgur/:user_id/:username" do |user_id, username|
  return [404, "Credentials not configured"] if !ENV["IMGUR_CLIENT_ID"]

  if user_id == "r"
    @subreddit = username
    data, @updated_at = App::Cache.cache("imgur.r", @subreddit.downcase, 60*60, 60) do
      response = App::Imgur.get("/gallery/r/#{@subreddit}")
      raise(App::ImgurError, response) if !response.success? || response.body.empty?
      response.json["data"].map do |image|
        image.slice("animated", "cover", "datetime", "description", "gifv", "height", "id", "images_count", "is_album", "nsfw", "score", "size", "title", "type", "width")
      end.to_json
    end
  else
    @user_id = user_id
    @username = username
    data, @updated_at = App::Cache.cache("imgur.user", @username.downcase, 60*60, 60) do
      # can't use user_id in this request unfortunately
      response = App::Imgur.get("/account/#{@username}/submissions")
      next "Error: This user no longer exists." if response.code == 404
      raise(App::ImgurError, response) if !response.success? || response.body.empty?
      response.json["data"].map do |image|
        image.slice("animated", "cover", "datetime", "description", "gifv", "height", "id", "images_count", "is_album", "nsfw", "score", "size", "title", "type", "width")
      end.to_json
    end
  end
  return [422, "Something went wrong. Try again later."] if data.nil?
  return [422, data] if data.start_with?("Error:")

  @data = JSON.parse(data)

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
  end.flatten.compact.map(&:grep_urls).flatten.tap { |urls| App::URL.resolve(urls) }

  erb :"imgur.atom"
end

get "/svtplay" do
  if /https?:\/\/(?:www\.)?svtplay\.se\/video\/[a-zA-Z0-9]+\/(?<program>[^\/]+)/ =~ params[:q]
    # https://www.svtplay.se/video/7181623/veckans-brott/veckans-brott-sasong-12-avsnitt-10
    # https://www.svtplay.se/video/jbrEL2D/veckans-brott/krimjournalister-journalistikens-nya-rockstjarnor
  elsif /https?:\/\/(?:www\.)?svtplay\.se\/(?<program>kategori\/[^\/]+)/ =~ params[:q]
    # https://www.svtplay.se/kategori/vetenskapens-varld
  elsif /https?:\/\/(www\.)?svtplay\.se\/(?<program>[^\/]+)/ =~ params[:q]
    # https://www.svtplay.se/veckans-brott
  else
    # it's probably a program name
    program = params[:q].downcase.gsub(/[:.]/, "").gsub(" ", "-").gsub("å", "a").gsub("ä", "a").gsub("ö", "o")
  end

  if program
    redirect Addressable::URI.parse("https://www.svtplay.se/#{program}/atom.xml").normalize.to_s, 301
  else
    return [404, "Could not find the program."]
  end
end

get "/favicon.ico" do
  redirect "/img/icon32.png", 301
end

get %r{/apple-touch-icon.*} do
  redirect "/img/icon128.png", 301
end

get "/opensearch.xml" do
  erb :opensearch
end

get "/health" do
  return [200, ""]
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
