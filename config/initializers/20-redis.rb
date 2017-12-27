# frozen_string_literal: true

begin
  $redis = Redis::Namespace.new(:rssbox)
rescue
  puts "Failed to connect to redis!"
end
