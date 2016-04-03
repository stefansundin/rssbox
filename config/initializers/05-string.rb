class String
  def to_line
    self.gsub("\n", " ")
  end

  def to_paragraphs(split="\n")
    self.split(split).reject { |line| line.ustrip == "" }.map { |line| "<p>#{line}</p>" }.join("\n")
  end

  def esc
    self.gsub("&","&amp;").gsub("<","&lt;")
  end

  def ustrip
    # remove extra unicode crap
    self.gsub(/[\u00a0\u3000]/,"").strip
  end

  def numeric?
    /^\d+$/ === self
  end

  def tz_offset?
    /^[-+]?\d+(\.\d+)?$/ === self
  end
end
