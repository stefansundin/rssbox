# frozen_string_literal: true
# https://dev.twitter.com/rest/reference/get/statuses/user_timeline

module App
  class TwitterError < HTTPError; end

  class Twitter < HTTP
    BASE_URL = "https://api.twitter.com/1.1"
    HEADERS = {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{ENV["TWITTER_ACCESS_TOKEN"]}",
    }
    ERROR_CLASS = TwitterError

    # https://developer.twitter.com/en/docs/twitter-api/v1/rate-limits
    @@ratelimit = {
      "/users/show" => {
        limit: 300,
      },
      "/statuses/user_timeline" => {
        limit: 1500,
      },
    }

    def self.ratelimit(endpoint)
      raise("fill in @@ratelimit information") if @@ratelimit[endpoint].nil?

      if @@ratelimit[endpoint][:reset].nil? || Time.now > Time.at(@@ratelimit[endpoint][:reset]+5)
        return @@ratelimit[endpoint][:limit], nil
      end

      return @@ratelimit[endpoint][:remaining], @@ratelimit[endpoint][:reset]
    end

    def self.get(*args, &block)
      response = super(*args, &block)
      if response.headers.has_key?("x-rate-limit-limit") \
        && response.headers.has_key?("x-rate-limit-remaining") \
        && response.headers.has_key?("x-rate-limit-reset")
        endpoint = args[0]
        @@ratelimit[endpoint][:limit] = response.headers["x-rate-limit-limit"][0].to_i
        @@ratelimit[endpoint][:remaining] = response.headers["x-rate-limit-remaining"][0].to_i
        @@ratelimit[endpoint][:reset] = response.headers["x-rate-limit-reset"][0].to_i
        $metrics[:ratelimit].set(response.headers["x-rate-limit-remaining"][0].to_i, labels: { service: "twitter", endpoint: endpoint })
      end
      return response
    end
  end
end

error App::TwitterError do |e|
  status 422
  "There was a problem talking to Twitter. Please try again in a moment."
end
