class FacebookPost < ActiveRecord::Base
  before_create :get_data

  def get_data
    response = HTTParty.get("https://graph.facebook.com/v2.3/#{id}?access_token=#{ENV["FACEBOOK_APP_ID"]}|#{ENV["FACEBOOK_APP_SECRET"]}")
    raise FacebookError.new(response) if !response.success?
  end
end
