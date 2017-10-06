# frozen_string_literal: true

class Time
  # always output time objects in RFC3339 format
  def to_s
    self.utc.strftime("%FT%TZ")
  end

  def readable(tz=nil)
    t = self
    if tz
      if ActiveSupport::TimeZone::MAPPING.flatten.include?(tz)
        t = t.in_time_zone(tz)
      elsif tz.tz_offset?
        # to get this offset from JavaScript, use: -new Date().getTimezoneOffset()/60
        # available offsets: ActiveSupport::TimeZone.all.map { |z| z.utc_offset/60/60.0 }.uniq
        t = t.in_time_zone(tz.to_f) rescue t
      end
    end
    t.strftime("%F %T %z")
  end
end
