# frozen_string_literal: true

# Helper function for nginx proxy that uses a subdir.
# Example use:
# location /rssbox/ {
#   proxy_pass http://unix:/home/deploy/rssbox/tmp/puma.sock:/;
#   proxy_set_header Host $host;
#   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#   proxy_set_header X-Forwarded-Proto $scheme;
#   proxy_set_header X-Forwarded-Url $scheme://$host$request_uri;
#   proxy_redirect $scheme://example.com/ /rssbox/;
# }

class Sinatra::Request
  def original_url
    env["HTTP_X_FORWARDED_URL"] || url
  end

  def root_url
    return base_url if !env["HTTP_X_FORWARDED_URL"] || env["HTTP_X_FORWARDED_URL"] == url
    forwarded_path = Addressable::URI.parse(env["HTTP_X_FORWARDED_URL"]).path
    uri = Addressable::URI.parse(url)
    uri.path = forwarded_path[0..(forwarded_path.length-uri.path.length-1)]
    uri.query = uri.fragment = nil
    uri.to_s
  end
end
