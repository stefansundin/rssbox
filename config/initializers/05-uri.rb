# URI.escape was removed in Ruby 3.0, this monkeypatches it back in.
# Required for the opengraph_parser gem to work properly.
# https://github.com/huyha85/opengraph_parser/pull/20

if !URI.respond_to?(:escape)
  module URI
    def self.escape(url)
      URI::Parser.new.escape(url)
    end
  end
end
