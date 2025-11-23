# frozen_string_literal: true

# By default, block everything
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
  config.x_xss_protection = "0"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = "no-referrer"
  config.csp = {
    default_src: %w('none'),
    base_src: %w('none'),
    script_src: SecureHeaders::OPT_OUT,
    upgrade_insecure_requests: true,
  }
  config.csp[:report_uri] = ENV["CSP_REPORT_URI"].split(",") if ENV["CSP_REPORT_URI"]

  # Allow unsafe-inline for better_errors in development mode
  if ENV["APP_ENV"] == "development"
    config.hsts = SecureHeaders::OPT_OUT
    config.csp.merge!({
      script_src: %w('unsafe-inline'),
      style_src: %w('unsafe-inline'),
      connect_src: %w('self'),
      upgrade_insecure_requests: false,
    })
  end
end

# Index page
SecureHeaders::Configuration.override(:index) do |config|
  config.referrer_policy = "strict-origin-when-cross-origin"
  config.csp.merge!({
    # "meta" values. these will shape the header, but the values are not included in the header.
    report_only: false,
    preserve_schemes: true,
    # directive values: these values will directly translate into source directives
    default_src: %w('none'),
    style_src: %w('self' cdn.jsdelivr.net),
    script_src: %w('self' cdn.jsdelivr.net code.jquery.com),
    img_src: %w('self' data:),
    form_action: %w('self' www.youtube.com vimeo.com imgur.com www.svtplay.se stefansundin.com www.paypal.com),
    connect_src: %w('self' *.fbcdn.net *.cdninstagram.com *.sndcdn.com),
    frame_ancestors: %w('none'),
  })

  # Allow unsafe-inline for better_errors in development mode
  if ENV["APP_ENV"] == "development"
    config.csp[:script_src] << "'unsafe-inline'"
    config.csp[:style_src] << "'unsafe-inline'"
  end
end

SecureHeaders::Configuration.override(:countdown) do |config|
  config.x_frame_options = SecureHeaders::OPT_OUT
  config.csp.merge!({
    # "meta" values. these will shape the header, but the values are not included in the header.
    report_only: false,
    preserve_schemes: true,
    # directive values: these values will directly translate into source directives
    default_src: %w('none'),
    style_src: %w('unsafe-inline'),
    script_src: %w('unsafe-inline'),
  })
end

SecureHeaders::Configuration.override(:twitch_embed) do |config|
  config.x_frame_options = SecureHeaders::OPT_OUT
  config.csp.merge!({
    # "meta" values. these will shape the header, but the values are not included in the header.
    report_only: false,
    preserve_schemes: true,
    # directive values: these values will directly translate into source directives
    default_src: %w('none'),
    style_src: %w('unsafe-inline'),
    script_src: %w('unsafe-inline'),
    frame_src: %w(https://player.twitch.tv),
  })
end
