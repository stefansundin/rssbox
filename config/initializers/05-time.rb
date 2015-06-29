class Time
  # always output time objects in RFC3339 format
  def to_s
    self.utc.strftime('%FT%TZ')
  end
end
