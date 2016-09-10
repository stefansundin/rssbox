require "net/http"
require "uri"

class String
  def to_line
    self.gsub("\n", " ")
  end

  def to_paragraphs(split="\n")
    self.split(split).reject { |line| line.ustrip == "" }.map { |line| "<p>#{line}</p>" }.join("\n")
  end

  def to_filename
    self.gsub(/[*?"<>|]/, "").gsub(":", ".").gsub(/\t+/, " ")
  end

  def esc
    self.gsub("&","&amp;").gsub("<","&lt;")
  end

  def ustrip
    # remove extra unicode crap
    self.gsub(/[\u00a0\u3000]/,"").strip
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
    URI::HTTP.new(uri.scheme.downcase, uri.userinfo, uri.host.downcase, port, uri.registry, uri.path, uri.opaque, uri.query, uri.fragment).to_s
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
    dest = $redis.hget("urls", url)
    return dest if dest

    dest = url
    catch :done do
      5.times do
        uri = URI.parse(dest)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          response = http.head(uri.request_uri)
          case response
          when Net::HTTPRedirection then
            if %w[
              ://www.youtube.com/das_captcha
              ://www.nytimes.com/glogin
              ://www.facebook.com/unsupportedbrowser
              ://play.spotify.com/error/browser-not-supported.php
              ://www.linkedin.com/uas/login
              ://www.theaustralian.com.au/remote/check_cookie.html
            ].any? { |s| response["location"].include?(s) }
              throw :done
            end
            if response["location"][0] == "/"
              uri = URI.parse(url)
              dest = uri.scheme + "://" + uri.host + response["location"]
            else
              dest = response["location"]
            end
          else
            throw :done
          end
        end
      end
    end

    # Remove SoundCloud tracking code
    if %r{^https?://soundcloud\.com/.+(?<tracking>/s-[0-9a-zA-Z]+)} =~ self
      dest = dest.gsub(tracking, "")
    end
    # Remove mysterious prclt tracking code
    dest = dest.gsub(/[?&#](?:__)?prclt[=-][^&]+/, "")

    $redis.hset("urls", url, dest)
    dest
  end

  def embed_html(request)
    if %r{^https?://www\.facebook\.com/.*/videos/(?<id>\d+)} =~ self
      <<-EOF
<iframe src="https://www.facebook.com/video/embed?video_id=#{id}" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen></iframe>
<p><a href="#{request.root_url}/facebook/download?url=#{id}">Download video</a></p>
      EOF
    elsif %r{^https?://(www\.|m\.)youtube\.com/(?:.*?[?&#](v=(?<id>[^&#]+)|list=(?<list>[^&#]+)|t=(?<t>[^&#]+)))+} =~ self or %r{^https?://youtu\.be/(?<id>[^?&#]+)(?:.*?[?&#](list=(?<list>[^&#]+)|t=(?<t>[^&#]+)))*} =~ self
      # https://www.youtube.com/watch?v=z5OGD5_9cA0&list=PL0QrZvg7QIgpoLdNFnEePRrU-YJfr9Be7&index=3&t=30s
      url = "https://www.youtube.com/embed/#{id}?rel=0"
      url += "&list=#{list}" if list
      if t and /(?:(?<h>\d+)h|(?<m>\d+)m|(?<s>\d+)s)+/ =~ t
        # https://youtu.be/wZZ7oFKsKzY?t=3h44m34s => start=13474
        start = 60*60*h.to_i + 60*m.to_i + s.to_i
        url += "&start=#{start}"
      end
      "<iframe width='640' height='360' src='#{url}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(www\.)?vimeo\.com/(?<id>\d+)} =~ self
      "<iframe width='853' height='480' src='https://player.vimeo.com/video/#{id}' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(www\.)?soundcloud\.com/(?<artist>[^/]+)/(?<set>sets/)?(?<track>[^/?#]+)} =~ self
      # https://soundcloud.com/infectedmushroom/liquid-smoke
      # https://soundcloud.com/infectedmushroom/sets/fields-of-grey-remixes
      height = set ? 450 : 166
      "<iframe width='853' height='#{height}' src='https://w.soundcloud.com/player/?url=#{self}&show_comments=false' frameborder='0' scrolling='no' allowfullscreen></iframe>"
    elsif %r{^https?://(www\.)?giphy\.com/gifs/(?:.*-)?(?<id>[0-9a-zA-Z]+)(/|\?|&|#|$)} =~ self
      "<img src='https://i.giphy.com/#{id}.gif'>"
    elsif %r{^https?://[a-z0-9\-._~:/?#\[\]@!$&'()*+,;=]+\.gif}i =~ self
      "<img src='#{self}'>"
    end
  end
end
