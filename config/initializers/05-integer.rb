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
end
