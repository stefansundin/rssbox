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

  def linkify_and_embed(request, embed_only="")
    nil
  end

  def embed_html(request)
    nil
  end

  def [](key)
    false
  end
end
