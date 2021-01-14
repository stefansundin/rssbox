# frozen_string_literal: true
# https://developer.vimeo.com/api/start

module App
  class VimeoError < HTTPError; end

  class Vimeo < HTTP
    BASE_URL = "https://api.vimeo.com"
    HEADERS = {
      "Authorization": "bearer #{ENV["VIMEO_ACCESS_TOKEN"]}",
    }
    ERROR_CLASS = VimeoError
  end
end

error App::VimeoError do |e|
  status 422
  "There was a problem talking to Vimeo. Please try again in a moment."
end
