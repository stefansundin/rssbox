# frozen_string_literal: true

begin
  $redis = Redis.new
rescue
  puts "Failed to connect to redis!"
end
