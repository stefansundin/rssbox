# frozen_string_literal: true

class NilClass
  def empty?
    true
  end

  def downcase
    nil
  end

  def to_line
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

  def linkify_and_embed(request=nil, embed_only="")
    nil
  end

  def embed_html(request=nil)
    nil
  end

  def [](key)
    false
  end
end
