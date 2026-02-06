module ActiveCanvas
  class Configuration
    # ==> Authentication
    # Authentication callback for public pages
    # Set to a proc/lambda that will be called as a before_action
    # Example: config.authenticate_public = -> { redirect_to login_path unless current_user }
    attr_accessor :authenticate_public

    # Authentication callback for admin pages
    # Set to a proc/lambda or method name symbol
    # Example: config.authenticate_admin = :authenticate_admin_user!
    # Example: config.authenticate_admin = -> { redirect_to login_path unless current_user&.admin? }
    attr_accessor :authenticate_admin

    # HTTP Basic Auth credentials (used when authenticate_admin = :http_basic_auth)
    attr_accessor :http_basic_user
    attr_accessor :http_basic_password

    # Parent controller class for admin controllers
    # Set to a string like "Admin::ApplicationController" to inherit authentication
    # Example: config.admin_parent_controller = "Admin::ApplicationController"
    attr_accessor :admin_parent_controller

    # Current user method name (used by AI features, version tracking, etc.)
    attr_accessor :current_user_method

    # ==> CSS Framework
    # Default CSS framework: :tailwind, :bootstrap5, :none
    # Can be overridden in admin settings
    attr_accessor :css_framework

    # ==> Media Uploads
    # Enable/disable file uploads
    attr_accessor :enable_uploads

    # Maximum upload size in bytes
    attr_accessor :max_upload_size

    # Allowed MIME types for uploads
    attr_accessor :allowed_content_types

    # Allow SVG uploads (disabled by default due to XSS risks)
    attr_accessor :allow_svg_uploads

    # Active Storage service name (nil = default service)
    attr_accessor :storage_service

    # Make uploads publicly accessible (false = use signed URLs)
    attr_accessor :public_uploads

    # ==> Editor Settings
    # Default blocks available in the editor
    attr_accessor :editor_blocks

    # Enable/disable specific editor features
    attr_accessor :enable_ai_features
    attr_accessor :enable_code_editor
    attr_accessor :enable_asset_manager

    # ==> Page Settings
    # Auto-save interval in seconds (0 = disabled)
    attr_accessor :autosave_interval

    # Maximum versions to keep per page (0 = unlimited)
    attr_accessor :max_versions_per_page

    # ==> Security
    # Sanitize HTML content on save
    attr_accessor :sanitize_content

    # Allowed HTML tags (when sanitize_content is true)
    attr_accessor :allowed_html_tags

    # Allowed HTML attributes (when sanitize_content is true)
    attr_accessor :allowed_html_attributes

    # ==> AI Security
    # Rate limit for AI requests (per minute per IP)
    attr_accessor :ai_rate_limit_per_minute

    # Maximum stream timeout for AI chat
    attr_accessor :ai_stream_timeout

    # Idle timeout for AI streaming (no data received)
    attr_accessor :ai_stream_idle_timeout

    # Maximum response size for AI streaming
    attr_accessor :ai_max_response_size

    # Maximum screenshot size (base64 encoded)
    attr_accessor :max_screenshot_size

    # Allowed hosts for AI-generated image downloads
    attr_accessor :allowed_ai_image_hosts

    # Dangerous content types that are always blocked
    DANGEROUS_CONTENT_TYPES = %w[
      application/x-executable
      application/x-sharedlib
      application/x-mach-binary
      text/html
      application/javascript
      text/javascript
      application/x-httpd-php
    ].freeze

    def initialize
      # Authentication - open by default (configure in initializer!)
      @authenticate_public = nil
      @authenticate_admin = nil
      @http_basic_user = nil
      @http_basic_password = nil
      @admin_parent_controller = "ActionController::Base"
      @current_user_method = :current_user

      # CSS Framework
      @css_framework = :tailwind

      # Media Uploads
      @enable_uploads = true
      @max_upload_size = 10.megabytes
      @allowed_content_types = %w[
        image/jpeg
        image/png
        image/gif
        image/webp
        image/avif
        application/pdf
      ]
      @allow_svg_uploads = false
      @storage_service = nil
      @public_uploads = false

      # Editor Settings
      @editor_blocks = :all
      @enable_ai_features = true
      @enable_code_editor = true
      @enable_asset_manager = true

      # Page Settings
      @autosave_interval = 60
      @max_versions_per_page = 50

      # Security
      @sanitize_content = true
      @allowed_html_tags = %w[
        h1 h2 h3 h4 h5 h6 p div span a img ul ol li
        table thead tbody tr th td
        section article header footer nav main aside
        figure figcaption blockquote pre code
        strong em b i u s mark small sub sup
        br hr
        form input button label select option textarea
        iframe video audio source
      ]
      @allowed_html_attributes = %w[
        class id style href src alt title target rel
        width height loading name type value placeholder
        disabled readonly checked selected multiple
        action method enctype
        controls autoplay loop muted poster
        frameborder allowfullscreen allow
      ]

      # AI Security
      @ai_rate_limit_per_minute = 30
      @ai_stream_timeout = 5.minutes
      @ai_stream_idle_timeout = 30.seconds
      @ai_max_response_size = 1.megabyte
      @max_screenshot_size = 10.megabytes
      @allowed_ai_image_hosts = %w[
        oaidalleapiprodscus.blob.core.windows.net
        dalleprodsec.blob.core.windows.net
      ]
    end

    # Get effective allowed content types (includes SVG if enabled, excludes dangerous types)
    def effective_allowed_content_types
      types = allowed_content_types.dup
      types << "image/svg+xml" if allow_svg_uploads
      types - DANGEROUS_CONTENT_TYPES
    end

    # Check if authentication is properly configured for production
    def enforce_authentication!
      return unless defined?(Rails) && Rails.env.production?
      return if authenticate_admin.present?
      return if admin_parent_controller != "ActionController::Base"

      raise SecurityError, <<~MSG
        [ActiveCanvas] Admin authentication is not configured!

        Your admin interface is currently open to anyone. Configure authentication in your initializer:

        ActiveCanvas.configure do |config|
          # Option 1: Use your app's authentication method (recommended)
          config.authenticate_admin = :authenticate_user!

          # Option 2: Inherit from your admin base controller
          config.admin_parent_controller = "Admin::ApplicationController"

          # Option 3: Use HTTP Basic Auth
          config.authenticate_admin = :http_basic_auth
          config.http_basic_user = "admin"
          config.http_basic_password = Rails.application.credentials.active_canvas_password
        end

        For development, you can use HTTP Basic Auth with default credentials,
        but ALWAYS configure proper authentication for production.
      MSG
    end

    # Check if HTTP Basic Auth is configured
    def http_basic_auth_configured?
      authenticate_admin == :http_basic_auth &&
        http_basic_user.present? &&
        http_basic_password.present?
    end

    # Helper to check if AI features are enabled
    def ai_available?
      @enable_ai_features
    end

    # Helper to check if Tailwind compilation is available
    def tailwind_compilation_available?
      @css_framework == :tailwind && defined?(Tailwindcss::Ruby)
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def config
      configuration
    end
  end
end
