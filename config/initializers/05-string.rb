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

    $redis.hset("urls", url, dest)
    dest
  end
end
