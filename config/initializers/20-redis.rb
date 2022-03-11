# frozen_string_literal: true

# Monkeypatch redis to throttle it from attempting to connect more often than once a second

class Redis
  class ThrottledConnectError < BaseConnectionError
  end

  class Client
    @@last_connect_error = nil

    # https://github.com/redis/redis-rb/blob/v4.6.0/lib/redis/client.rb#L379-L399
    def establish_connection
      if @@last_connect_error && Time.now < @@last_connect_error + 1
        raise ThrottledConnectError, "Throttled connection attempt to Redis on #{location}"
      end

      server = @connector.resolve.dup

      @options[:host] = server[:host]
      @options[:port] = Integer(server[:port]) if server.include?(:port)

      @connection = @options[:driver].connect(@options)
      @pending_reads = 0
    rescue TimeoutError,
           SocketError,
           Errno::EADDRNOTAVAIL,
           Errno::ECONNREFUSED,
           Errno::EHOSTDOWN,
           Errno::EHOSTUNREACH,
           Errno::ENETUNREACH,
           Errno::ENOENT,
           Errno::ETIMEDOUT,
           Errno::EINVAL => error

      @@last_connect_error = Time.now
      raise CannotConnectError, "Error connecting to Redis on #{location} (#{error.class})"
    end
  end
end

if ENV.has_key?("REDIS_URL")
  $redis = Redis.new({
    reconnect_attempts: 0,
  })
end
