# frozen_string_literal: true
# https://api.imgur.com/endpoints

module App
  class ImgurError < HTTPError; end

  class Imgur < HTTP
    BASE_URL = "https://api.imgur.com/3"
    HEADERS = {
      "Authorization" => "Client-ID #{ENV["IMGUR_CLIENT_ID"]}",
    }
    ERROR_CLASS = ImgurError
  end
end

error App::ImgurError do |e|
  status 422
  "There was a problem talking to Imgur. Please try again in a moment."
end
