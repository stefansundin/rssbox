class Integer
  def to_duration
    seconds = self % 60
    minutes = (self / 60) % 60
    hours = self / 3600
    if hours > 0
      sprintf("%d:%02d:%02d", hours, minutes, seconds)
    else
      sprintf("%d:%02d", minutes, seconds)
    end
  end

  def to_filesize(digits=2)
    units = %w[B kB MB GB TB PB EB ZB YB]
    n = self
    i = 0
    while n > 1000 and i < units.length do
      n = n / 1000.0
      i += 1
    end
    size = i > 0 ? n.round(digits) : n
    "#{size} #{units[i]}"
  end
end
