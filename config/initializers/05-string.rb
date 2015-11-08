class String
  def to_line
    self.gsub("\n", " ")
  end

  def esc
    self.gsub("<","&lt;").gsub("&","&amp;")
  end
end
