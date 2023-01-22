# frozen_string_literal: true

# This code provides a framework to conveniently cache data from third-party services.
# The end result is a much better experience when RSS clients request feeds very frequently, and it helps negate the effect of abusive use of the service.
# The data is stored in plain files on the filesystem. Note that the files are not proactively cleaned up so you may want to periodically delete the cache yourself. The caller decides how long the cached should be considered good.
# In the case of unexpected errors (e.g. an exception was raised), an empty file is written to denote a "negative" cache. This helps throttle errors and prevents error conditions from sending a lot of requests to third-party services. The negative cache duration is usually pretty short.
# If there is cached data and but the cache has expired, then the caller receives a copy of this cached data, and in certain conditions it can decide to continue using the cached data even though it has technically expired (e.g. if the ratelimit is close to being met).
# To save on disk space, the caller should only cache the data that is needed from the service. Data may also be pre-processed where it makes sense.
# When incompatible changes are made, the version number in the cache directory should be incremented.
# On case-insensitive filesystems (Windows, macOS), there is a chance that the cache keys may collide (e.g. for YouTube channel ids), therefore a case-sensitive filesystem is recommended for production usage.

require "fileutils"

module App
  class Cache
    DIR = File.expand_path(ENV["CACHE_DIR"] || "../tmp/cache", __dir__) + "/v2"

    # Create cache directory
    FileUtils.mkdir_p(DIR)
    # Clean up old files if running in development
    if ENV["APP_ENV"] == "development"
      Dir["#{DIR}/*.rssbox-cache"].each do |file_path|
        File.unlink(file_path)
      end
    end

    def self.cache(cache_key_prefix, cache_key, cache_duration, negative_cache_duration, &block)
      # Try to make the cache key safer in case it contains user input
      cache_key = cache_key.gsub("/", "-").gsub(":", "-")
      fn = "#{DIR}/#{cache_key_prefix}.#{cache_key}.rssbox-cache"
      # Generate some jitter to use when checking the cache durations
      cache_duration_jitter = rand(5*60)
      negative_cache_duration_jitter = rand(10)

      if File.file?(fn)
        # There is cached data
        stat = File.stat(fn)

        if stat.size > 0
          # There is cached data with contents
          cached_data = File.read(fn)
          $metrics[:cache_read_bytes].increment(by: cached_data.bytesize, labels: { prefix: cache_key_prefix })
          if Time.now < stat.mtime+cache_duration+cache_duration_jitter
            $metrics[:cache_hits_duration_seconds].observe(Time.now-stat.mtime, labels: { prefix: cache_key_prefix })
            return cached_data, stat.mtime
          end
        else
          if Time.now < stat.mtime+negative_cache_duration+negative_cache_duration_jitter
            # A negative cache is in place and it is still active
            $metrics[:cache_hits_negative_total].increment(labels: { prefix: cache_key_prefix })
            return nil, stat.mtime
          end
        end

        # The cached data has expired
        begin
          $metrics[:cache_misses_total].increment(labels: { prefix: cache_key_prefix })
          data = yield(cached_data, stat)
        rescue
          $metrics[:cache_errors_total].increment(labels: { prefix: cache_key_prefix })
          if cached_data
            # Update mtime so a yield is not attempted for negative_cache_duration
            FileUtils.touch(fn, mtime: Time.now-cache_duration+negative_cache_duration)
            $metrics[:cache_hits_duration_seconds].observe(Time.now-stat.mtime, labels: { prefix: cache_key_prefix })
            return cached_data, stat.mtime
          end
          # Trigger negative cache and re-raise the exception
          FileUtils.touch(fn)
          raise
        end

        if data == cached_data
          # The new data is exactly the same as the previously cached data, so just update the file mtime
          FileUtils.touch(fn, mtime: Time.now)
          $metrics[:cache_updates_unchanged_total].increment(labels: { prefix: cache_key_prefix })
        else
          # Write new data
          File.write(fn, data || "")
          $metrics[:cache_size_bytes].increment(by: (data&.bytesize || 0) - (cached_data&.bytesize || 0), labels: { prefix: cache_key_prefix })
          $metrics[:cache_written_bytes].increment(by: (data&.bytesize || 0), labels: { prefix: cache_key_prefix })
          $metrics[:cache_updates_changed_total].increment(labels: { prefix: cache_key_prefix })
        end

        return data, Time.now
      end

      # There is no cached data
      $metrics[:cache_misses_total].increment(labels: { prefix: cache_key_prefix })
      begin
        data = yield
      rescue
        # Trigger negative cache and re-raise the exception
        FileUtils.touch(fn)
        $metrics[:cache_errors_total].increment(labels: { prefix: cache_key_prefix })
        $metrics[:cache_keys_total].increment(labels: { prefix: cache_key_prefix })
        raise
      end
      File.write(fn, data || "")
      $metrics[:cache_size_bytes].increment(by: (data&.bytesize || 0), labels: { prefix: cache_key_prefix })
      $metrics[:cache_written_bytes].increment(by: (data&.bytesize || 0), labels: { prefix: cache_key_prefix })
      $metrics[:cache_keys_total].increment(labels: { prefix: cache_key_prefix })

      return data, Time.now
    end
  end
end
