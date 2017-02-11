require "net/http"
require "uri"
require "resolv-replace.rb"

class String
  URL_REGEXP = /\bhttps?:\/\/[a-z0-9\/\-+=_#%\.~?\[\]@!$&'()*,;:\|]+(?<![%\.~?\[\]@!$&'()*,;:])/i
  SPOTIFY_REGEXP = /\bspotify:(?:artist|album|track|user):[0-9a-zA-Z:]+\b/

  @@url_cache = {}

  def to_line
    self.gsub("\n", " ")
  end

  def to_paragraphs(split="\n")
    self.split(split).reject { |line| line.ustrip == "" }.map { |line| "<p>#{line.strip}</p>" }.join("\n")
  end

  def to_filename
    self.to_line.gsub(/[*?"<>|]/, "").gsub(":", ".").gsub(/[\/\\]/, "-").gsub(/\t+/, " ").gsub(/\.+(\.[a-z]+)$/, '\1')
  end

  def esc
    self.gsub("&","&amp;").gsub("<","&lt;")
  end

  def ustrip
    # remove extra unicode crap
    self.gsub(/[\u00a0\u3000]/,"").strip
  end

  def undent
    # from https://github.com/Homebrew/brew/blob/c9c7f462d37500549127efba96c7a25e5c70de4a/Library/Homebrew/extend/string.rb#L2-L4
    gsub(/^[ \t]{#{(slice(/^[ \t]+/) || '').length}}/, "")
  end

  def numeric?
    /^\d+$/ === self
  end

  def tz_offset?
    /^[-+]?\d+(\.\d+)?$/ === self
  end

  def url_ext
    uri = URI.parse(self)
    File.extname(uri.path)
  end

  def normalize_url
    uri = URI.parse(self)
    port = uri.port if (uri.scheme == "http" and uri.port != 80) or (uri.scheme == "https" and uri.port != 443)
    path = uri.path.empty? ? "/" : uri.path
    URI::HTTP.new(uri.scheme.downcase, uri.userinfo, uri.host.downcase, port, uri.registry, path, uri.opaque, uri.query, uri.fragment).to_s
  end

  def https
    self.gsub(/^http:/, "https:")
  end

  def short_host
    uri = URI.parse(self)
    if uri.host[0..3] == "www."
      uri.host[4..-1]
    else
      uri.host
    end
  end

  def resolve_url
    url = self.normalize_url
    dest = @@url_cache[url]
    if dest
      return url if dest == ""
      return dest
    end
    dest = $redis.hget("urls", url)
    if dest
      @@url_cache[url] = dest
      return url if dest == ""
      return dest
    end

    dest = url
    catch :done do
      5.times do
        begin
          uri = URI.parse(dest)
          throw :done if uri.host.nil?
          opt = {
            use_ssl: uri.scheme == "https",
            open_timeout: 3,
            read_timeout: 3,
          }
          Net::HTTP.start(uri.host, uri.port, opt) do |http|
            response = http.head(uri.request_uri)
            case response
            when Net::HTTPRedirection then
              if response["location"][0] == "/"
                # relative redirect
                uri = URI.parse(url)
                redirect_url = uri.scheme + "://" + uri.host + response["location"]
              elsif /^https?:\/\/./ =~ response["location"]
                # absolute redirect
                redirect_url = response["location"]
              else
                # bad redirect
                throw :done
              end
              redirect_url = URI.escape(redirect_url) # Some redirects do not url encode properly, such as http://amzn.to/2aDg49F
              if %w[
                ://www.youtube.com/das_captcha
                ://www.nytimes.com/glogin
                ://www.facebook.com/unsupportedbrowser
                ://play.spotify.com/error/browser-not-supported.php
                ://www.linkedin.com/uas/login
                ://www.theaustralian.com.au/remote/check_cookie.html
                ://signin.aws.amazon.com/
                ://accounts.google.com/ServiceLogin
              ].any? { |s| redirect_url.include?(s) }
                throw :done
              end
              dest = redirect_url
            else
              throw :done
            end
          end
        rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError, EOFError
          throw :done
        end
      end
    end

    # Remove SoundCloud tracking code
    if %r{^https?://soundcloud\.com/.+(?<tracking>/s-[0-9a-zA-Z]+)} =~ self
      dest = dest.gsub(tracking, "")
    end
    # Remove youtu.be crap
    dest = dest.gsub(/&feature=youtu\.be(?=&|#|$)/, "")
    # Remove mysterious prclt tracking code
    dest = dest.gsub(/(?:__)?prclt[=-][^&]+/, "")
    # Remove utm_ and sc_ codes
    # https://aws.amazon.com/podcasts/aws-podcast/?utm_content=bufferf4ae0&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer
    # https://aws.amazon.com/about-aws/whats-new/2016/09/aws-config-console-now-displays-api-events-associated-with-configuration-changes/?sc_channel=sm&sc_campaign=launch_Config_ead85f34&sc_publisher=tw_go&sc_content=AWS_Config_add_support_for_viewing_CloudTrail_API_events_from_Config_console&sc_geo=globaly
    dest = dest.gsub(/(?:utm|sc)_[^&]+/, "")
    # Remove #_=_
    dest = dest.gsub(/#_=_$/, "")
    # Remove #. tracking codes
    dest = dest.gsub(/#\..*$/, "")
    # Remove unnecessary ampersands (possibly caused by the above)
    dest = dest.gsub(/\?&+/, "?")
    # Remove trailing ?&#
    dest = dest.gsub(/[?&#]+$/, "")

    if url == dest
      # save some space
      @@url_cache[url] = ""
      $redis.hset("urls", url, "")
    else
      @@url_cache[url] = dest
      $redis.hset("urls", url, dest)
    end
    dest
  end

  def linkify
    result = self.gsub(SPOTIFY_REGEXP) do |uri|
      "https://play.spotify.com/#{uri.gsub(":","/")}"
    end
    result.gsub(URL_REGEXP) do |url|
      dest = url.resolve_url
      "<a href='#{dest}' title='#{url}' rel='noreferrer'>#{dest}</a>"
    end
  end

  def linkify_and_embed(request=nil, embed_only="")
    embeds = []
    result = self.gsub(SPOTIFY_REGEXP) do |uri|
      "https://play.spotify.com/#{uri.gsub(":","/")}"
    end
    result.gsub!(URL_REGEXP) do |url|
      dest = url.resolve_url
      html = dest.embed_html(request)
      embeds.push(html) if html and !embeds.include?(html)
      "<a href='#{dest}' title='#{url}' rel='noreferrer'>#{dest}</a>"
    end
    embed_only.scan(URL_REGEXP) do |url|
      dest = url.resolve_url
      html = dest.embed_html(request)
      embeds.push(html) if html and !embeds.include?(html)
    end
    return result + embeds.map { |html| "\n" + html }.join
  end

  def embed_html(request=nil)
    root_url = request ? request.root_url : ""
    if %r{^https?://www\.facebook\.com/.*/videos/(?<id>\d+)} =~ self or %r{^https?://www\.facebook\.com/video/embed\?video_id=(?<id>\d+)} =~ self
      <<-EOF.undent
        <iframe src="https://www.facebook.com/video/embed?video_id=#{id}" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen></iframe>
        <a href="https://www.facebook.com/video/embed?video_id=#{id}">Open embed</a> | <a href="#{root_url}/facebook/download?url=#{id}">Download video</a> | <a href="#{root_url}/?download=#{CGI.escape("https://www.facebook.com/video/embed?video_id=#{id}")}">Download video with nice filename</a>
      EOF
    elsif %r{^https?://(?:www\.|m\.)youtube\.com/(?:.*?[?&#](v=(?<id>[^&#]+)|list=(?<list>[^&#]+)|t=(?<t>[^&#]+)))+} =~ self or %r{^https?://youtu\.be/(?<id>[^?&#]+)(?:.*?[?&#](list=(?<list>[^&#]+)|t=(?<t>[^&#]+)))*} =~ self
      # https://www.youtube.com/watch?v=z5OGD5_9cA0&list=PL0QrZvg7QIgpoLdNFnEePRrU-YJfr9Be7&index=3&t=30s
      url = "https://www.youtube.com/embed/#{id}?rel=0"
      url += "&list=#{list}" if list
      if t and /(?:(?<h>\d+)h|(?<m>\d+)m|(?<s>\d+)s)+/ =~ t
        # https://youtu.be/wZZ7oFKsKzY?t=3h44m34s => start=13474
        start = 60*60*h.to_i + 60*m.to_i + s.to_i
        url += "&start=#{start}"
      end
      "<iframe width='640' height='360' src='#{url}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(?:www\.)?vimeo\.com/(?<id>\d+)} =~ self
      "<iframe width='853' height='480' src='https://player.vimeo.com/video/#{id}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(?:www\.)?instagram\.com/p/(?<id>[^/?#]+)} =~ self
      "<iframe src='https://www.instagram.com/p/#{id}/embed/' width='612' height='710' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(?:www\.)?twitch\.tv/(?:videos/(?<vod_id>\d+)|(?<channel_name>[^/]+)(?:/v/(?<vod_id>\d+))?).*(?:[?&#](?<t>t=[^&#]+))?} =~ self
      # https://www.twitch.tv/videos/25133028
      # https://www.twitch.tv/gamesdonequick
      # https://www.twitch.tv/gamesdonequick/v/76877760?t=20h38m50s
      url = "https://player.twitch.tv/?"
      url += vod_id ? "video=v#{vod_id}" : "channel=#{channel_name}"
      url += "&time=#{t}" if t
      <<-EOF.undent
        <iframe width="853" height="480" src="#{url}" frameborder="0" scrolling="no" allowfullscreen></iframe>
        <a href="#{url}">Open embed</a> | <a href="#{root_url}/twitch/watch?url=#{vod_id || channel_name}&open">Open in VLC</a> | <a href="#{root_url}/twitch/download?url=#{vod_id || channel_name}">Download video</a>
      EOF
    elsif %r{^https?://(?:www\.)?soundcloud\.com/(?<artist>[^/]+)/(?<set>sets/)?(?<track>[^/?#]+)} =~ self
      # https://soundcloud.com/infectedmushroom/liquid-smoke
      # https://soundcloud.com/infectedmushroom/sets/fields-of-grey-remixes
      height = set ? 450 : 166
      "<iframe width='853' height='#{height}' src='https://w.soundcloud.com/player/?url=#{self}&show_comments=false' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(?:open|play)\.spotify\.com/(?<path>[^?#]+)} =~ self
      "<iframe width='300' height='380' src='https://embed.spotify.com/?uri=spotify:#{path.gsub("/",":")}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(?:www\.)?giphy\.com/gifs/(?:.*-)?(?<id>[0-9a-zA-Z]+)(/|\?|&|#|$)} =~ self
      "<img src='https://i.giphy.com/#{id}.gif'>"
    elsif %r{^https?://[a-z0-9\-._~:/?#\[\]@!$&'()*+,;=]+\.gifv}i =~ self
      "<iframe width='640' height='538' src='#{self.https}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://[a-z0-9\-._~:/?#\[\]@!$&'()*+,;=]+\.(?:gif|jpg|png)(?::large)?}i =~ self
      "<img src='#{self.https}'>"
    elsif %r{^https?://[a-z0-9\-._~:/?#\[\]@!$&'()*+,;=]+\.mp4}i =~ self
      query = CGI.parse(URI.parse(self).query)
      width = query["w"][0] || "640"
      height = query["h"][0] || "538"
      "<iframe width='#{width}' height='#{height}' src='#{self}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://amp\.twimg\.com/v/.+}i =~ self
      "<iframe width='640' height='600' src='#{self}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    end
  end
end
