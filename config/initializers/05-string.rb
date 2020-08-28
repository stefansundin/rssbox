# frozen_string_literal: true

require "net/http"
require "resolv-replace.rb"

class String
  URL_REGEXP = /\bhttps?:\/\/(?:[a-z0-9\/\-+=_#%\.~?\[\]@!$&'*,;:\|]|\([a-z0-9\/\-+=_#%\.~?\[\]@!$&'*,;:\|]+\))+(?<![%\.~?\[\]@!$&'*,;:])/i
  SPOTIFY_REGEXP = /\bspotify:(?:artist|album|track|user):[0-9a-zA-Z:]+\b/

  def to_line
    self.ustrip.gsub(/\s+/, " ")
  end

  def to_paragraphs(split="\n")
    self.split(split).reject { |line| line.ustrip == "" }.map { |line| "<p>#{line.strip}</p>" }.join("\n")
  end

  def to_filename
    self.to_line.gsub(/[*?"'<>|]/, "").gsub(":", ".").gsub(/[\/\\]/, "-").gsub(/\t+/, " ").gsub(/\.+(\.[a-z0-9]+)$/, '\1')
  end

  def titelize
    self.gsub("\n", " ").gsub(String::URL_REGEXP) do |url|
      dest = URL.lookup(url)
      "[#{dest.short_host}]"
    end
  end

  def truncate(i=140)
    omission = "…" # &hellip;
    if self.length > i
      self[0...i-omission.length] + omission
    else
      self
    end
  end

  def or(alt)
    return alt if self.ustrip == ""
    self
  end

  def esc
    self.gsub("&","&amp;").gsub("<","&lt;")
  end

  def ustrip
    # remove extra unicode crap
    self.gsub(/[\u00a0\u3000]/,"").strip
  end

  def strip_tags
    self.gsub(%r{</?[^>]+?>}, '')
  end

  def numeric?
    /^\d+$/ === self
  end

  def tz_offset?
    /^[-+]\d{2}:\d{2}$/ === self
  end

  def parse_duration
    if /^(?:(?<h>\d+)h)?(?:(?<m>\d+)m)?(?:(?<s>\d+)s)?$/ =~ self
      result = 0
      result += 3600 * h.to_i if h
      result += 60 * m.to_i if m
      result += s.to_i if s
      result
    end
  end

  def parse_pt
    if /^PT(?:(?<h>\d+)H)?(?:(?<m>\d+)M)?(?:(?<s>\d+)S)?$/ =~ self
      result = 0
      result += 3600 * h.to_i if h
      result += 60 * m.to_i if m
      result += s.to_i if s
      result
    end
  end

  def url_ext
    uri = Addressable::URI.parse(self)
    File.extname(uri.path)
  end

  def https
    self.gsub(/^http:/, "https:")
  end

  def short_host
    uri = Addressable::URI.parse(self).normalize!
    if uri.host[0..3] == "www."
      uri.host[4..]
    else
      uri.host
    end
  rescue
    "invalid-url"
  end

  def grep_urls
    self.scan(URL_REGEXP)
  end

  def linkify
    result = self.gsub(SPOTIFY_REGEXP) do |uri|
      "https://play.spotify.com/#{uri.gsub(":","/")}"
    end
    result.gsub(URL_REGEXP) do |url|
      dest = URL.lookup(url)
      "<a href='#{dest.esc}' title='#{url.esc}' rel='noreferrer'>#{dest.esc}</a>"
    end
  end

  def linkify_and_embed(request=nil, embed_only="")
    embeds = []
    result = self.gsub(SPOTIFY_REGEXP) do |uri|
      "https://play.spotify.com/#{uri.gsub(":","/")}"
    end
    result.gsub!(URL_REGEXP) do |url|
      dest = URL.lookup(url)
      html = dest.embed_html(request)
      embeds.push(html) if html && !embeds.include?(html)
      "<a href='#{dest.esc}' title='#{url.esc}' rel='noreferrer'>#{dest.esc}</a>"
    end
    embed_only.scan(URL_REGEXP) do |url|
      dest = URL.lookup(url)
      html = dest.embed_html(request)
      embeds.push(html) if html && !embeds.include?(html)
    end
    return result + embeds.map { |html| "\n" + html }.join
  end

  def embed_html(request=nil)
    root_url = request ? request.root_url : ""
    if %r{^https?://www\.facebook\.com/.*/videos/(?:vb\.\d+\/)?(?<id>\d+)} =~ self || %r{^https?://www\.facebook\.com/video/embed\?video_id=(?<id>\d+)} =~ self
      <<~EOF
        <iframe width="1280" height="720" src="https://www.facebook.com/video/embed?video_id=#{id}" frameborder="0" scrolling="no" allowfullscreen referrerpolicy="no-referrer"></iframe>
        <a href="https://www.facebook.com/video/embed?video_id=#{id}" rel="noreferrer">Open embed</a>
      EOF
    elsif %r{^https?://(?:www\.|m\.)youtube\.com/(?:.*?[?&#](v=(?<id>[^&#]+)|list=(?<list>[^&#]+)|(?:t|time_continue)=(?<t>[^&#]+)))+} =~ self || %r{^https?://(?:youtu\.be|(?:www\.)?youtube\.com/embed)/(?<id>[^?&#]+)(?:.*?[?&#](list=(?<list>[^&#]+)|(?:t|time_continue)=(?<t>[^&#]+)))*} =~ self
      # https://www.youtube.com/watch?v=z5OGD5_9cA0&list=PL0QrZvg7QIgpoLdNFnEePRrU-YJfr9Be7&index=3&t=30s
      url = "https://www.youtube.com/embed/#{id}?rel=0"
      url += "&list=#{list}" if list
      if t
        if /(?:(?<h>\d+)h|(?<m>\d+)m|(?<s>\d+)s)+/ =~ t
          # https://youtu.be/wZZ7oFKsKzY?t=3h44m34s => start=13474
          t = 60*60*h.to_i + 60*m.to_i + s.to_i
        end
        url += "&start=#{t}"
      end
      "<iframe width='640' height='360' src='#{url}' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://(?:www\.)?vimeo\.com/(?<id>\d+)} =~ self
      "<iframe width='853' height='480' src='https://player.vimeo.com/video/#{id}' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://(?:www\.)?instagram\.com/(?:p|tv)/(?<id>[^/?#]+)} =~ self
      "<iframe width='612' height='710' src='https://www.instagram.com/p/#{id}/embed/' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://(?:www\.)?twitch\.tv/(?:videos/(?<vod_id>\d+)|(?<channel_name>[^/]+)(?:/(?:v|video)/(?<vod_id>\d+))?).*?(?:[?&#](?:t|time)=(?<t>[^&#]+))?} =~ self && !%w[directory broadcast].include?(channel_name)
      # https://www.twitch.tv/videos/76877760?t=20h38m50s
      # https://www.twitch.tv/gamesdonequick
      # https://www.twitch.tv/gamesdonequick/video/76877760 (legacy url)
      # https://www.twitch.tv/gamesdonequick/v/76877760 (legacy url)
      url = "#{request.root_url}/twitch-embed.html#autoplay=false&"
      url += vod_id ? "video=#{vod_id}" : "channel=#{channel_name}"
      url += "&time=#{t}" if t
      <<~EOF
        <iframe width="853" height="480" src="#{url}" frameborder="0" scrolling="no" allowfullscreen referrerpolicy="no-referrer"></iframe>
        <a href="#{url}" rel="noreferrer">Open embed</a> | <a href="#{root_url}/twitch/watch?url=#{vod_id || channel_name}&open">Open in VLC</a> | <a href="#{root_url}/twitch/download?url=#{vod_id || channel_name}">Download video</a>
      EOF
    elsif %r{^https?://(?:www\.)?soundcloud\.com/(?<artist>[^/]+)/(?<set>sets/)?(?<track>[^/?#]+)} =~ self
      # https://soundcloud.com/infectedmushroom/liquid-smoke
      # https://soundcloud.com/infectedmushroom/sets/fields-of-grey-remixes
      height = set ? 450 : 166
      "<iframe width='853' height='#{height}' src='https://w.soundcloud.com/player/?url=#{self}&show_comments=false' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://(?:open|play)\.spotify\.com/(?<path>[^?#]+)} =~ self
      "<iframe width='300' height='380' src='https://embed.spotify.com/?uri=spotify:#{path.gsub("/",":")}' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://sverigesradio\.se/sida/artikel.aspx} =~ self
      # http://sverigesradio.se/sida/artikel.aspx?programid=83&artikel=6819392
      # http://sverigesradio.se/sida/embed?url=http://sverigesradio.se/sida/artikel.aspx%3Fprogramid=83%26artikel=6819392
      "<iframe width='853' height='155' src='https://sverigesradio.se/sida/embed#{Addressable::URI.new(query: "url=#{self}").normalize.to_s}' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://gfycat\.com/(?:gifs/detail/)?(?<id>[^@\/?#]+)} =~ self
      "<iframe width='640' height='273' src='https://gfycat.com/ifr/#{id}' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://(?:www\.)?giphy\.com/gifs/(?:.*-)?(?<id>[0-9a-zA-Z]+)(/|\?|&|#|$)} =~ self
      "<img src='https://i.giphy.com/#{id}.gif' referrerpolicy='no-referrer'>"
    elsif %r{^https?://[a-z0-9\-._~:/?#\[\]@!$&'()*+,;=]+\.gifv}i =~ self
      "<iframe width='640' height='538' src='#{self.https}' frameborder='0' scrolling='no' allowfullscreen referrerpolicy='no-referrer'></iframe>"
    elsif %r{^https?://[a-z0-9\-._~:/?#\[\]@!$&'()*+,;=]+\.(?:gif|jpg|png)(?::large)?}i =~ self
      "<img src='#{self.https}' referrerpolicy='no-referrer'>"
    elsif %r{^https?://video\.twimg\.com/.+/(?<width>\d+)x(?<height>\d+)/.+\.mp4}i =~ self
      "<video width='#{width}' height='#{height}' controls='controls'><source type='video/mp4' src='#{self}'></video>"
    elsif %r{^https?://[a-z0-9\-._~:/?#\[\]@!$&'()*+,;=]+\.mp4}i =~ self
      uri = URI.parse(self)
      query = CGI.parse(uri.query || "").merge(CGI.parse(uri.fragment || "")) { |key,oldval,newval| oldval + newval }
      width = query["w"][0] || "640"
      height = query["h"][0] || "538"
      "<video width='#{width}' height='#{height}' controls='controls'><source type='video/mp4' src='#{self}'></video>"
    elsif %r{^https?://amp\.twimg\.com/v/.+}i =~ self
      "<video width='#{width}' height='#{height}' controls='controls'><source type='video/mp4' src='#{self}'></video>"
    end
  end
end
