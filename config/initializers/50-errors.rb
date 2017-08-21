class PartyError < StandardError
  def initialize(request)
    @request = request
  end

  def request
    @request
  end

  def data
    @request.parsed_response
  end

  def message
    @request.to_s
  rescue
    "#{@request.code} #{@request.body}"
  end
end
