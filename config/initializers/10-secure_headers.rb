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
  config.x_xss_protection = "1; mode=block"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = "no-referrer"
  config.csp = {
    default_src: %w('none'),
    script_src: SecureHeaders::OPT_OUT,
    block_all_mixed_content: true,
  }
  config.csp[:report_uri] = ENV["CSP_REPORT_URI"].split(",") if ENV["CSP_REPORT_URI"]

  # Allow unsafe-inline for better_errors in development mode
  if ENV["APP_ENV"] == "development"
    config.hsts = SecureHeaders::OPT_OUT
    config.csp.merge!({
      script_src: %w('unsafe-inline'),
      style_src: %w('unsafe-inline'),
      connect_src: %w('self'),
    })
  end
end

# Index page
SecureHeaders::Configuration.override(:index) do |config|
  config.referrer_policy = "origin-when-cross-origin"
  config.csp.merge!({
    # "meta" values. these will shape the header, but the values are not included in the header.
    report_only: false,
    preserve_schemes: true,
    # directive values: these values will directly translate into source directives
    default_src: %w('none'),
    style_src: %w('self' *.bootstrapcdn.com),
    script_src: %w('self' *.bootstrapcdn.com code.jquery.com cdn.jsdelivr.net stefansundin.github.io www.google-analytics.com),
    font_src: %w(*.bootstrapcdn.com),
    img_src: %w('self' www.google-analytics.com),
    form_action: %w('self' www.youtube.com vimeo.com imgur.com www.svtplay.se stefansundin.com www.paypal.com),
    connect_src: %w('self' *.fbcdn.net *.cdninstagram.com *.sndcdn.com),
  })

  # Allow unsafe-inline for better_errors in development mode
  if ENV["APP_ENV"] == "development"
    config.csp[:script_src] << "'unsafe-inline'"
    config.csp[:style_src] << "'unsafe-inline'"
  end
end

SecureHeaders::Configuration.override(:live) do |config|
  config.csp.merge!({
    # "meta" values. these will shape the header, but the values are not included in the header.
    report_only: false,
    preserve_schemes: true,
    # directive values: these values will directly translate into source directives
    default_src: %w('none'),
    style_src: %w('self' *.bootstrapcdn.com),
    script_src: %w('self' *.bootstrapcdn.com code.jquery.com cdnjs.cloudflare.com cdn.rawgit.com),
    font_src: %w(*.bootstrapcdn.com),
    img_src: %w('self' graph.facebook.com scontent.xx.fbcdn.net i.ytimg.com static-cdn.jtvnw.net),
    connect_src: %w(graph.facebook.com www.googleapis.com api.twitch.tv),
  })
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
