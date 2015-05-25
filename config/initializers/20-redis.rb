begin
  $redis = Redis::Namespace.new :rssbox
rescue => e
  puts "Failed to connect to redis!"
  puts e.backtrace
end
