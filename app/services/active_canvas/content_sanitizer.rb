module ActiveCanvas
  class ContentSanitizer
    class << self
      # Sanitize HTML content using Rails' built-in sanitizer
      def sanitize_html(content)
        return content if content.blank?
        return content unless ActiveCanvas.config.sanitize_content

        config = ActiveCanvas.config

        # Use Rails' SafeListSanitizer with our allowed tags/attributes
        sanitizer = Rails::HTML5::SafeListSanitizer.new

        # Build scrubber for data-* and aria-* attributes
        scrubber = PermissiveAttributeScrubber.new(
          allowed_tags: config.allowed_html_tags,
          allowed_attributes: config.allowed_html_attributes
        )

        sanitizer.sanitize(content, scrubber: scrubber)
      end

      # Sanitize CSS content (basic XSS protection)
      def sanitize_css(css)
        return css if css.blank?
        return css unless ActiveCanvas.config.sanitize_content

        # Remove potentially dangerous CSS patterns
        sanitized = css.dup

        # Remove JavaScript URLs
        sanitized.gsub!(/url\s*\(\s*["']?\s*javascript:/i, "url(blocked:")

        # Remove expression() (IE-specific XSS vector)
        sanitized.gsub!(/expression\s*\(/i, "blocked(")

        # Remove behavior: (IE-specific XSS vector)
        sanitized.gsub!(/behavior\s*:/i, "blocked:")

        # Remove -moz-binding (Firefox XSS vector)
        sanitized.gsub!(/-moz-binding\s*:/i, "blocked:")

        # Remove @import with javascript
        sanitized.gsub!(/@import\s+["']?\s*javascript:/i, "/* blocked */")

        sanitized
      end

      # Sanitize JavaScript (very restrictive - mainly for tracking scripts)
      def sanitize_js(js)
        return js if js.blank?

        # For now, we just return the JS as-is
        # Users who enable JS are accepting responsibility
        # In the future, could add CSP nonce support
        js
      end
    end

    # Custom scrubber that allows data-* and aria-* attributes
    class PermissiveAttributeScrubber < Rails::HTML::PermitScrubber
      def initialize(allowed_tags:, allowed_attributes:)
        super()
        self.tags = allowed_tags
        @allowed_attributes = allowed_attributes
      end

      def allowed_node?(node)
        return false unless super
        true
      end

      def scrub_attribute(node, attr_node)
        attr_name = attr_node.name.downcase

        # Allow explicitly listed attributes
        return if @allowed_attributes.include?(attr_name)

        # Allow data-* attributes
        return if attr_name.start_with?("data-")

        # Allow aria-* attributes
        return if attr_name.start_with?("aria-")

        # Check for dangerous attribute values (javascript: URLs, event handlers)
        if dangerous_attribute?(attr_name, attr_node.value)
          attr_node.remove
          return
        end

        # Remove unlisted attributes
        attr_node.remove
      end

      private

      def dangerous_attribute?(name, value)
        # Event handlers
        return true if name.start_with?("on")

        # JavaScript URLs in href, src, etc.
        if %w[href src action formaction].include?(name)
          return true if value.to_s.strip.downcase.start_with?("javascript:")
          return true if value.to_s.strip.downcase.start_with?("data:text/html")
          return true if value.to_s.strip.downcase.start_with?("vbscript:")
        end

        false
      end
    end
  end
end
