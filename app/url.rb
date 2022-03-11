# frozen_string_literal: true

module App
  class URL
    URL_RESOLUTION_DISABLED = ($redis.nil? || ENV["URL_RESOLUTION_DISABLED"] == "true")

    @@cache = {}

    def self.lookup(url)
      return url if URL_RESOLUTION_DISABLED

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
      return nil if URL_RESOLUTION_DISABLED

      pending = urls.map do |url|
        Addressable::URI.parse(url).normalize.to_s rescue url
      end.uniq.select do |url|
        if !force
          next false if @@cache.has_key?(url)
          dest = $redis.get("url:#{url}")
          if dest
            @@cache[url] = dest
            next false
          end
        end
        true
      end

      threads = []
      max_concurrency = ENV["URL_MAX_CONCURRENCY"]&.to_i || 5
      num_threads = [max_concurrency, pending.length].min
      while threads.length < num_threads
        thread = Thread.new do
          while url = pending.pop
            URL.resolve_url(url)
          end
        end
        threads.push(thread)
      end
      threads.map(&:join)
      return nil
    rescue Redis::BaseConnectionError
      return nil
    end

    private

    def self.resolve_url(url)
      dest = url
      catch :done do
        5.times do
          uri = Addressable::URI.parse(dest)
          throw :done if uri.host.nil?
          opts = {
            use_ssl: uri.scheme == "https",
            open_timeout: 3,
            read_timeout: 3,
          }
          Net::HTTP.start(uri.host, uri.port, opts) do |http|
            response = http.head(uri.request_uri)
            case response
            when Net::HTTPRedirection then
              if response["location"][0] == "/"
                # relative redirect
                uri = Addressable::URI.parse(dest)
                next_url = uri.scheme + "://" + uri.host + response["location"]
              elsif /^https?:\/\/./ =~ response["location"]
                # absolute redirect
                next_url = response["location"]
              else
                # bad redirect
                throw :done
              end
              # Some servers do not encode the url properly, such as http://amzn.to/2aDg49F
              next_uri = Addressable::URI.parse(next_url)
              next_url = next_uri.normalize.to_s
              if next_url.start_with?("https://bitly.com/a/warning") && next_uri.query_values["url"]
                # http://bit.ly/2om6hZ4
                # https://bitly.com/a/warning?hash=2om6hZ4&url=http://soundbar.uvtix.com/event/uv1609432840dt180407rm0/infected-mushroom-dj-set-in-dolby-atmos/
                next_url = next_uri.query_values["url"]
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
                https://virtual.awsevents.com/user/login
              ].any? { |s| next_url.start_with?(s) }
                throw :done
              end
              dest = next_url
            else
              throw :done
            end
          end
        rescue => e
          puts "Exception trying to resolve URL #{dest}: #{e.message}"
          throw :done
        end
      end

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
      $redis.set("url:#{url}", dest)

      $metrics[:urls_resolved_total].increment
    end
  end
end
