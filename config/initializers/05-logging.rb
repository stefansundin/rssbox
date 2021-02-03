# frozen_string_literal: true

if ENV.has_key?("CLOGGER")
  # disable Sinatra's logger
  disable :logging

  # https://yhbt.net/clogger/
  # this format is similar to "Combined", but without $time_local and $http_user_agent (and using $ip instead of $remote_addr)
  # Combined: $remote_addr - $remote_user [$time_local] $request" $status $response_length "$http_referer" "$http_user_agent"
  # removing time and user-agent saves ~50% on log filesize
  # the purpose of ~ is to allow for easier grepping with -E '^~' (i.e. filtering out exceptions and other crap)
  opts = {
    reentrant: true,
    format: ENV["CLOGGER_FORMAT"] || '~ $ip "$request" $status $response_length "$http_referer"',
  }
  if ENV.has_key?("CLOGGER_FILE")
    opts[:path] = ENV["CLOGGER_FILE"]
  else
    opts[:logger] = $stdout
  end
  use Clogger, opts
end
