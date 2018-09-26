# frozen_string_literal: true

class URL
  @@cache = {}

  def self.url_in_cache?(url)
    return true if @@cache.has_key?(url)
    dest = $redis.hget("urls", url)
    if dest
      @@cache[url] = dest
      return true
    end
    return false
  end

  def self.lookup(url)
    url = Addressable::URI.parse(url).normalize.to_s rescue url
    dest = @@cache[url]
    if dest
      if dest == ""
        return url
      end
      return dest
    end
    # puts "Unresolved url: #{url}"
    return url
  end

  def self.resolve(urls, force=false)
    hydra = Typhoeus::Hydra.new(max_concurrency: ENV["TYPHOEUS_MAX_CONCURRENCY"] || 5)
    urls.uniq.each do |url|
      url = Addressable::URI.parse(url).normalize.to_s rescue url
      next if url_in_cache?(url) && !force
      request = Typhoeus::Request.new(url, method: :head, timeout: 3)
      request.on_complete(&request_complete(hydra, url))
      request.on_body {} # make Typhoeus discard the body and save some RAM
      hydra.queue(request)
    end
    hydra.run
    return nil
  end

  def self.save_resolution(url, dest)
    # Remove SoundCloud tracking code
    if %r{^https?://soundcloud\.com/.+(?<tracking>/s-[0-9a-zA-Z]+)} =~ dest
      dest = dest.gsub(tracking, "")
    end
    # Remove youtu.be crap
    dest = dest.gsub(/(?<=[?&])feature=youtu\.be(?=&|#|$)/, "")
    # Remove mysterious prclt tracking code
    dest = dest.gsub(/(?<=[?&])(?:__)?prclt[=-][^&#]+/, "")
    # Remove Amazon tracking codes
    # https://aws.amazon.com/podcasts/aws-podcast/?utm_content=bufferf4ae0&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer
    # https://aws.amazon.com/about-aws/whats-new/2016/09/aws-config-console-now-displays-api-events-associated-with-configuration-changes/?sc_channel=sm&sc_campaign=launch_Config_ead85f34&sc_publisher=tw_go&sc_content=AWS_Config_add_support_for_viewing_CloudTrail_API_events_from_Config_console&sc_geo=globaly
    # https://aws.amazon.com/summits/washington-dc/?trkCampaign=DCSummit2017&trk=sm_twitter&adbsc=social_20170427_71906466&adbid=z123jzf53ojbjbm0l221ez2jtoeqijchx04&adbpl=gp&adbpr=100017971115449920316
    dest = dest.gsub(/(?<=[?&])(?:(?:utm|sc)[_\-][a-z]+|utm|adb(?:sc|id|pr|pl)|trk(?:Campaign)?|mkt_tok|campaign-id|aff|linkId)=[^&#]+/, "")
    # Remove #_=_
    dest = dest.gsub(/#_=_$/, "")
    # Remove #. tracking codes
    dest = dest.gsub(/#\..*$/, "")
    # Remove unnecessary ampersands (possibly caused by the above)
    while dest[/(\?.+?)&&+/]
      dest = dest.gsub(/(\?.+?)&&+/, "\\1&")
    end
    dest = dest.gsub(/\?&+/, "?")
    # Remove trailing ?&#
    dest = dest.gsub(/[?&#]+(?:$|(?=#))/, "")

    # puts "#{url} => #{dest}"
    dest = "" if url == dest
    @@cache[url] = dest
    $redis.hset("urls", url, dest)
  end

  private

  def self.request_complete(hydra, original_url, redirect_counter=0)
    return lambda do |response|
      url = response.request.url
      # puts "#{url}: #{response.code}"
      follow_redirect = (response.code >= 300 && response.code < 400)
      if follow_redirect && redirect_counter < 5
        location = response.headers["location"]
        if location[0] == "/"
          # relative redirect
          uri = Addressable::URI.parse(url)
          redirect_url = uri.scheme + "://" + uri.host + location
        elsif /^https?:\/\/./ =~ location
          # absolute redirect
          redirect_url = location
        else
          # bad redirect
          follow_redirect = false
        end
        if follow_redirect
          # Some servers do not encode the url properly, such as http://amzn.to/2aDg49F
          uri = Addressable::URI.parse(redirect_url)
          redirect_url = uri.normalize.to_s
          if redirect_url.start_with?("https://bitly.com/a/warning") && uri.query_values["url"]
            # http://bit.ly/2om6hZ4
            # https://bitly.com/a/warning?hash=2om6hZ4&url=http://soundbar.uvtix.com/event/uv1609432840dt180407rm0/infected-mushroom-dj-set-in-dolby-atmos/
            redirect_url = uri.query_values["url"]
          end
          if %w[
            https://www.youtube.com/das_captcha
            https://www.nytimes.com/glogin
            https://www.facebook.com/unsupportedbrowser
            https://play.spotify.com/error/browser-not-supported.php
            https://www.linkedin.com/uas/login
            https://www.theaustralian.com.au/remote/check_cookie.html
            https://signin.aws.amazon.com/
            https://accounts.google.com/ServiceLogin
          ].any? { |s| redirect_url.start_with?(s) }
            follow_redirect = false
          end
        end
        if follow_redirect
          request = Typhoeus::Request.new(redirect_url, method: :head, timeout: 3)
          request.on_complete(&request_complete(hydra, original_url, redirect_counter+1))
          request.on_body {}
          hydra.queue(request)
          return
        end
      end
      save_resolution(original_url, url)
    end
  end
end
