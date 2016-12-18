class Array
  def pick(v)
    v if self.include?(v)
  end

  def linkify_and_embed(request)
    arr = self.compact
    text = arr.shift
    text.linkify_and_embed(request, arr.join("\n"))
  end
end
