SecureHeaders::Configuration.default do |config|
  config.cookies = {
    secure: true,
    httponly: true,
    samesite: {
      strict: true
    }
  }
  config.hsts = "max-age=31536000; includeSubdomains; preload"
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = "origin-when-cross-origin"
  config.csp = {
    # "meta" values. these will shape the header, but the values are not included in the header.
    report_only: false,
    preserve_schemes: true,

    # directive values: these values will directly translate into source directives
    default_src: %w('none'),
    style_src: %w('self' *.bootstrapcdn.com),
    script_src: %w('self' *.bootstrapcdn.com code.jquery.com stefansundin.github.io www.google-analytics.com),
    font_src: %w(*.bootstrapcdn.com),
    img_src: %w('self' www.google-analytics.com),
    form_action: %w('self' www.youtube.com vimeo.com imgur.com www.svtplay.com stefansundin.com),
    connect_src: %w('self' *.fbcdn.net *.cdninstagram.com *.cdn.vine.co *.sndcdn.com),
    child_src: %w(mdo.github.io),
    block_all_mixed_content: true,
    # upgrade_insecure_requests: true,
  }
  config.csp[:report_uri] = ENV["CSP_REPORT_URI"].split(",") if ENV["CSP_REPORT_URI"]
end

# Allow unsafe-inline for better_errors in development mode
configure :development do
  SecureHeaders::Configuration.override(:default) do |config|
    config.csp[:script_src] << "'unsafe-inline'"
    config.csp[:style_src] << "'unsafe-inline'"
    # config.csp[:upgrade_insecure_requests] = false
  end
end
