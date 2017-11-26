# frozen_string_literal: true

configure :deployment do
  Exception.class_eval do
    alias :backtrace_prior_to_monkey_patch :backtrace
    alias :full_backtrace :backtrace_prior_to_monkey_patch

    def backtrace
      # If this function is called from Sinatra, then we want to only print a partial backtrace in order to cut down on log filesize
      if caller_locations(1,1)[0].path.end_with?("/lib/sinatra/base.rb")
        return full_backtrace.select { |l| !l["/lib/ruby/gems/"] }
      end
      return full_backtrace
    end
  end
end
