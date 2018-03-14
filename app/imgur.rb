# frozen_string_literal: true
# https://api.imgur.com/endpoints

class ImgurError < HTTPError; end

class Imgur < HTTP
  BASE_URL = "https://api.imgur.com/3"
  HEADERS = {
    "Authorization" => "Client-ID #{ENV["IMGUR_CLIENT_ID"]}",
  }
  ERROR_CLASS = ImgurError
end

error ImgurError do |e|
  status 503
  "There was a problem talking to Imgur. Please try again in a moment."
end
