# Helper function for nginx proxy
# Example use:
# location /rssbox/ {
#   proxy_pass http://unix:/home/deploy/rssbox/tmp/unicorn.sock:/;
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
end
