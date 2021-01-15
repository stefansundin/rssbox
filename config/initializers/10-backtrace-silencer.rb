# frozen_string_literal: true

configure :production do
  Exception.class_eval do
    alias :backtrace_prior_to_monkey_patch :backtrace
    alias :full_backtrace :backtrace_prior_to_monkey_patch

    # Monkey-patch the backtrace method in order to return a custom backtrace so that we can cut down on log filesize
    def backtrace
      # If this function is called from Sinatra, then we want to return a partial backtrace in order to print fewer lines to stdout
      if caller_locations(1,1)[0].path.end_with?("/lib/sinatra/base.rb")
        # For some errors, we don't care about the stack trace at all
        if exception.is_a?(App::InstagramRatelimitError)
          return []
        end
        # Otherwise, remove all lines from files in the bundle directory
        return full_backtrace.reject { |l| l.start_with?("/app/vendor/bundle/ruby/") }
      end
      return full_backtrace
    end
  end
end
