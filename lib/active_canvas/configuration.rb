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

    # Active Storage service name (nil = default service)
    attr_accessor :storage_service

    # Make uploads publicly accessible
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

    def initialize
      # Authentication - open by default (configure in initializer!)
      @authenticate_public = nil
      @authenticate_admin = nil
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
        image/svg+xml
        image/avif
        application/pdf
      ]
      @storage_service = nil
      @public_uploads = true

      # Editor Settings
      @editor_blocks = :all
      @enable_ai_features = true
      @enable_code_editor = true
      @enable_asset_manager = true

      # Page Settings
      @autosave_interval = 60
      @max_versions_per_page = 50

      # Security
      @sanitize_content = false
      @allowed_html_tags = nil
    end

    # Helper to check if AI features are available
    def ai_available?
      @enable_ai_features && defined?(RubyLLM)
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
