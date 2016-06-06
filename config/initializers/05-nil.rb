class NilClass
  def empty?
    true
  end

  def to_paragraphs(split="\n")
    nil
  end

  def esc
    nil
  end

  def [](key)
    false
  end
end
