module ActiveCanvas
  class Configuration
    # CSS Framework: :vanilla, :bootstrap, :tailwind
    attr_accessor :css_framework

    # Include host app's stylesheets in editor canvas
    attr_accessor :include_host_assets

    # Host app stylesheets to include (if include_host_assets = true)
    attr_accessor :host_stylesheets

    # Enable image uploads
    attr_accessor :enable_uploads

    # Maximum upload size in bytes (default: 10MB)
    attr_accessor :max_upload_size

    # Allowed upload content types
    attr_accessor :allowed_content_types

    # Storage service name for media uploads (should match a service in storage.yml)
    # Set to :public for a public S3 bucket, or nil to use the default service
    attr_accessor :storage_service

    # Whether to make uploaded files publicly accessible (sets ACL to public-read on S3)
    attr_accessor :public_uploads

    def initialize
      @css_framework = :tailwind
      @include_host_assets = true
      @host_stylesheets = ["application"]
      @enable_uploads = true
      @max_upload_size = 10.megabytes
      @allowed_content_types = %w[
        image/jpeg
        image/png
        image/gif
        image/webp
        image/svg+xml
      ]
      @storage_service = nil  # Use default Active Storage service
      @public_uploads = true  # Make uploads public by default
    end

    def css_framework_url
      case css_framework
      when :tailwind
        "https://cdn.tailwindcss.com"
      when :bootstrap
        "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
      else
        nil
      end
    end
  end
end
