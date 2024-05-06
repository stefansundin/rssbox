# frozen_string_literal: true

module App
  class GoogleError < HTTPError; end

  class Google < HTTP
    BASE_URL = "https://www.googleapis.com"
    PARAMS = "key=#{ENV["GOOGLE_API_KEY"]}"
    ERROR_CLASS = GoogleError
  end
end

error App::GoogleError do |e|
  status 422
  if (e.data["error"]["errors"][0]["reason"] == "accessNotConfigured" rescue false)
    "Please enable the appropriate API for this project in the Google Developer Console."
  else
    "There was a problem talking to Google. Please try again in a moment."
  end
end
