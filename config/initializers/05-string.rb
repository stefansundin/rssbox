class String
  def to_line
    self.gsub("\n", " ")
  end

  def esc
    self.gsub("<","&lt;")
  end
end
