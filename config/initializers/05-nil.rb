class NilClass
  def empty?
    true
  end

  def downcase
    nil
  end

  def to_paragraphs(split="\n")
    nil
  end

  def esc
    nil
  end

  def linkify
    nil
  end

  def [](key)
    false
  end
end
