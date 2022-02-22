# frozen_string_literal: true

class Array
  def pick(v)
    v if self.include?(v)
  end

  def linkify_and_embed(request)
    arr = self.compact
    text = arr.shift
    text.linkify_and_embed(request, arr.join("\n"))
  end

  # sort_fs sorts files in subdirectories lower
  def sort_fs
    self.sort.sort { |a,b| a.count("/") <=> b.count("/") }
  end
end
