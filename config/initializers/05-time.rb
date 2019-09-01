# frozen_string_literal: true

class Time
  # always output time objects in RFC3339 format
  def to_s
    self.utc.strftime("%FT%TZ")
  end

  def readable(tz=nil)
    t = self
    if tz
      if tz.is_a?(TZInfo::DataTimezone)
        t = tz.to_local(t)
      else
        t = t.getlocal(tz) rescue t
      end
    end
    t.strftime("%F %T %z")
  end
end
