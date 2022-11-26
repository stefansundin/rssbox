# frozen_string_literal: true
# export RUBYOPT=--enable-frozen-string-literal

require "sinatra"
require "./config/application"
require "open-uri"

before do
  content_type :text
end

before %r{/(?:go|twitter|youtube|vimeo|instagram|periscope|soundcloud|mixcloud|twitch|speedrun|dailymotion|imgur|svtplay)} do
  if !request.user_agent&.include?("Mozilla/") || !request.referer&.start_with?("#{request.base_url}/")
    halt [403, "This endpoint should not be used by a robot. RSS Box is open source so you should instead reimplement the thing you need in your own application."]
  end
  halt [400, "Insufficient parameters."] if params[:q].empty?
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
  if /^https?:\/\/(?:mobile\.)?twitter\.com\// =~ params[:q]
    redirect Addressable::URI.new(path: "/twitter", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.|gaming\.)?youtu(?:\.be|be\.com)/ =~ params[:q]
    redirect Addressable::URI.new(path: "/youtube", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?instagram\.com/ =~ params[:q]
    redirect Addressable::URI.new(path: "/instagram", query_values: params).normalize.to_s, 301
  elsif /^https?:\/\/(?:www\.)?(?:periscope|pscp)\.tv/ =~ params[:q]
    redirect Addressable::URI.new(path: "/periscope", query_values: params).normalize.to_s, 301
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

get %r{/twitter/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [404, "Credentials not configured"] if !ENV["TWITTER_ACCESS_TOKEN"]

  @user_id = id
  @username = CGI.unescape(username)
  include_rts = %w[0 1].pick(params[:include_rts]) || "1"
  exclude_replies = %w[0 1].pick(params[:exclude_replies]) || "0"

  erb :"twitter.atom"
end

get "/youtube/:channel_id/:username" do |channel_id, username|
  return [404, "Credentials not configured"] if !ENV["GOOGLE_API_KEY"]

  if params.has_key?(:q)
    @query = params[:q]
    @title = "\"#{@query}\" from #{username}"
  else
    @title = "#{username} on YouTube"
  end

  erb :"youtube.atom"
end

get %r{/instagram/(?<user_id>\d+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id
  @user = CGI.unescape(username)

  type = %w[videos photos].pick(params[:type]) || "posts"

  @title = @user
  @title += "'s #{type}" if type != "posts"
  @title += " on Instagram"

  erb :"instagram.atom"
end

get %r{/periscope/(?<id>[^/]+)/(?<username>.+)} do |id, username|
  @id = id
  @user = CGI.unescape(username)

  erb :"periscope.atom"
end

get %r{/soundcloud/(?<id>\d+)/(?<username>.+)} do |id, username|
  return [404, "Credentials not configured"] if !ENV["SOUNDCLOUD_CLIENT_ID"]

  @id = id

  @user = CGI.unescape(username)
  @username = CGI.unescape(username)

  erb :"soundcloud.atom"
end

get %r{/mixcloud/(?<username>[^/]+)/(?<user>.+)} do |username, user|
  @username = CGI.unescape(username)
  @user = CGI.unescape(user)

  erb :"mixcloud.atom"
end

get %r{/twitch/directory/game/(?<id>\d+)/(?<game_name>.+)} do |id, game_name|
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

  @id = id
  @type = "game"
  type = %w[all upload archive highlight].pick(params[:type]) || "all"

  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/directory/game/#{game_name}").normalize.to_s

  @title = game_name
  @title += " highlights" if type == "highlight"
  @title += " on Twitch"

  erb :"twitch.atom"
end

get %r{/twitch/(?<id>\d+)/(?<user>.+)} do |id, user|
  return [404, "Credentials not configured"] if !ENV["TWITCH_CLIENT_ID"]

  @id = id
  @type = "user"


  type = %w[all upload archive highlight].pick(params[:type]) || "all"
  @user = CGI.unescape(user)
  @alternate_url = Addressable::URI.parse("https://www.twitch.tv/#{user.downcase}").normalize.to_s

  @title = user
  @title += "'s highlights" if type == "highlight"
  @title += " on Twitch"

  erb :"twitch.atom"
end

get "/speedrun/:id/:abbr" do |id, abbr|
  @id = id
  @abbr = abbr

  erb :"speedrun.atom"
end

get %r{/dailymotion/(?<user_id>[a-z0-9]+)/(?<username>.+)} do |user_id, username|
  @user_id = user_id
  @username = CGI.unescape(username)

  erb :"dailymotion.atom"
end

get "/imgur/:user_id/:username" do |user_id, username|
  return [404, "Credentials not configured"] if !ENV["IMGUR_CLIENT_ID"]

  if user_id == "r"
    @subreddit = username
  else
    @user_id = user_id
    @username = username
  end

  erb :"imgur.atom"
end

get "/dilbert" do
  erb :"dilbert.atom"
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
