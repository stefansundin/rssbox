
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
  end
end

def httparty_error(r)
  "#{r.request.path.to_s}: #{r.code} #{r.message}: #{r.body}. #{r.headers.to_h.to_json}"
end
