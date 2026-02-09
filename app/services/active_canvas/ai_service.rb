module ActiveCanvas
  class AiService
    class ImageValidationError < StandardError; end
    class ScreenshotValidationError < StandardError; end

    # Allowed image types for screenshot-to-code
    ALLOWED_SCREENSHOT_TYPES = %w[png jpeg jpg webp gif].freeze

    # Magic bytes for image type validation
    IMAGE_MAGIC_BYTES = {
      "png" => "\x89PNG".b,
      "jpeg" => "\xFF\xD8\xFF".b,
      "jpg" => "\xFF\xD8\xFF".b,
      "webp" => "RIFF".b,
      "gif" => "GIF8".b
    }.freeze

    # Maximum download size for AI-generated images
    MAX_IMAGE_DOWNLOAD_SIZE = 10.megabytes

    class << self
      def generate_text(prompt:, model: nil, context: nil, &block)
        AiConfiguration.configure_ruby_llm!
        model ||= Setting.ai_default_text_model

        chat = RubyLLM.chat(model: model)
        chat.with_instructions(build_system_prompt(context)) if context.present?

        if block_given?
          chat.ask(prompt, &block)
        else
          chat.ask(prompt)
        end
      end

      def generate_image(prompt:, model: nil)
        AiConfiguration.configure_ruby_llm!
        model ||= Setting.ai_default_image_model

        image = RubyLLM.paint(prompt, model: model)
        store_generated_image(image.url, prompt)
      end

      def screenshot_to_code(image_data:, model: nil, additional_prompt: nil)
        AiConfiguration.configure_ruby_llm!
        model ||= Setting.ai_default_vision_model
        framework = Setting.css_framework

        prompt = build_screenshot_prompt(framework, additional_prompt)

        # RubyLLM expects a file path, not a data URL
        # Save base64 image to a temp file
        tempfile = save_base64_to_tempfile(image_data)

        begin
          chat = RubyLLM.chat(model: model)
          response = chat.ask(prompt, with: { image: tempfile.path })
          extract_html(response.content)
        ensure
          tempfile.close
          tempfile.unlink
        end
      end

      private

      def build_system_prompt(context)
        framework = Setting.css_framework
        <<~PROMPT
          You are an expert web designer creating content for a visual page builder.
          Generate clean, semantic HTML.

          #{framework_guidelines(framework)}

          General guidelines:
          - Use proper semantic HTML5 elements (section, article, header, nav, etc.)
          - Include responsive design patterns
          - Return ONLY the HTML code, no explanations or markdown code blocks
          - Do not include <html>, <head>, or <body> tags - just the content
          - Use placeholder images from https://placehold.co/ when images are needed

          #{context}
        PROMPT
      end

      def build_screenshot_prompt(framework, additional)
        base = <<~PROMPT
          Convert this screenshot into clean HTML.

          #{framework_guidelines(framework)}

          Requirements:
          - Create semantic, accessible HTML5 structure
          - Make it fully responsive
          - Use placeholder images from https://placehold.co/ for any images
          - Match the layout, colors, and typography as closely as possible
          - Return ONLY the HTML code, no explanations or markdown code blocks
          - Do not include <html>, <head>, or <body> tags - just the content
        PROMPT

        additional.present? ? "#{base}\n\nAdditional instructions: #{additional}" : base
      end

      def framework_guidelines(framework)
        case framework.to_s
        when "tailwind"
          <<~GUIDELINES
            CSS Framework: Tailwind CSS v4

            You MUST use Tailwind CSS utility classes exclusively for all styling. Do NOT use inline styles or custom CSS.

            Tailwind v4 rules:
            - Use slash syntax for opacity: bg-blue-500/50, text-black/75 (NOT bg-opacity-50 or text-opacity-75)
            - Use modern color syntax: bg-red-500/20 instead of bg-red-500 bg-opacity-20
            - Use arbitrary values with square brackets when needed: w-[72rem], text-[#1a2b3c]
            - Use the new shadow and ring syntax: shadow-sm, ring-1 ring-gray-200
            - Prefer gap-* over space-x-*/space-y-* for flex and grid layouts
            - Use size-* for equal width and height: size-8 instead of w-8 h-8
            - Use grid with grid-cols-subgrid where appropriate
            - All legacy utilities removed in v4 are forbidden (bg-opacity-*, text-opacity-*, divide-opacity-*, etc.)
          GUIDELINES
        when "bootstrap5"
          <<~GUIDELINES
            CSS Framework: Bootstrap 5

            Use Bootstrap 5 classes exclusively for all styling. Do NOT use inline styles or custom CSS.

            Bootstrap 5 rules:
            - Use the grid system: container, row, col-*, col-md-*, col-lg-*
            - Use Bootstrap utility classes: d-flex, justify-content-center, align-items-center, p-3, m-2, etc.
            - Use Bootstrap components: card, btn, navbar, alert, badge, etc.
            - Use responsive breakpoints: sm, md, lg, xl, xxl
            - Use spacing utilities: p-*, m-*, gap-*
            - Use text utilities: text-center, fw-bold, fs-*, text-muted
            - Use background utilities: bg-primary, bg-light, bg-dark, etc.
          GUIDELINES
        else
          <<~GUIDELINES
            CSS Framework: None (vanilla CSS)

            Use inline styles for all styling since no CSS framework is loaded.

            Vanilla CSS rules:
            - Apply all styles via the style attribute directly on HTML elements
            - Use modern CSS: flexbox, grid, clamp(), min(), max()
            - Ensure responsive behavior with relative units (%, rem, vw) and media queries via <style> blocks when necessary
            - Use CSS custom properties (variables) in a <style> block for consistent theming
          GUIDELINES
        end
      end

      def store_generated_image(url, prompt)
        require "open-uri"

        uri = URI.parse(url)
        validate_image_url!(uri)

        filename = "ai_generated_#{Time.current.to_i}_#{SecureRandom.hex(4)}.png"

        # Download with timeout and size limits
        tempfile = uri.open(
          read_timeout: 30,
          open_timeout: 10,
          "User-Agent" => "ActiveCanvas/#{ActiveCanvas::VERSION rescue '1.0'}"
        )

        # Check downloaded size
        if tempfile.size > MAX_IMAGE_DOWNLOAD_SIZE
          tempfile.close
          raise ImageValidationError, "Downloaded image too large: #{tempfile.size} bytes (max #{MAX_IMAGE_DOWNLOAD_SIZE})"
        end

        # Validate content type from response
        content_type = tempfile.content_type rescue "image/png"
        unless content_type&.start_with?("image/")
          tempfile.close
          raise ImageValidationError, "Invalid content type: #{content_type}"
        end

        media = Media.new(filename: filename)
        media.file.attach(io: tempfile, filename: filename, content_type: content_type)
        media.metadata = { "ai_generated" => true, "ai_prompt" => prompt.truncate(500) }
        media.save!
        media
      ensure
        tempfile&.close
      end

      def validate_image_url!(uri)
        allowed_hosts = ActiveCanvas.config.allowed_ai_image_hosts

        unless uri.scheme.in?(%w[http https])
          raise ImageValidationError, "Invalid URL scheme: #{uri.scheme}"
        end

        # Check if host is in allowed list (supports subdomain matching)
        host_allowed = allowed_hosts.any? do |allowed|
          uri.host == allowed || uri.host&.end_with?(".#{allowed}")
        end

        unless host_allowed
          Rails.logger.warn "[ActiveCanvas] AI image from untrusted host: #{uri.host}"
          # For now, log a warning but allow the download
          # Uncomment the line below to enforce strict host validation:
          # raise ImageValidationError, "Untrusted image host: #{uri.host}"
        end
      end

      def extract_html(content)
        # Remove markdown code blocks if present
        html = content.to_s
        html = html.gsub(/```html\n?/i, "")
        html = html.gsub(/```\n?/, "")
        html.strip
      end

      def save_base64_to_tempfile(data_url)
        max_size = ActiveCanvas.config.max_screenshot_size

        # Check size before decoding (base64 is ~33% larger than binary)
        if data_url.bytesize > (max_size * 1.4)
          raise ScreenshotValidationError, "Screenshot data too large (max #{max_size / 1.megabyte}MB)"
        end

        # Extract base64 data from data URL (data:image/png;base64,...)
        if data_url.start_with?("data:")
          unless data_url.start_with?("data:image/")
            raise ScreenshotValidationError, "Invalid image data URL: must be an image"
          end

          # Parse the data URL with strict type matching
          pattern = %r{^data:image/(#{ALLOWED_SCREENSHOT_TYPES.join('|')});base64,(.+)$}i
          matches = data_url.match(pattern)

          unless matches
            raise ScreenshotValidationError, "Invalid or unsupported image format. Allowed: #{ALLOWED_SCREENSHOT_TYPES.join(', ')}"
          end

          extension = matches[1].downcase
          base64_data = matches[2]
        else
          # Assume raw base64 data (default to PNG)
          extension = "png"
          base64_data = data_url
        end

        # Decode base64
        begin
          image_binary = Base64.strict_decode64(base64_data)
        rescue ArgumentError => e
          raise ScreenshotValidationError, "Invalid base64 data: #{e.message}"
        end

        # Check decoded size
        if image_binary.bytesize > max_size
          raise ScreenshotValidationError, "Screenshot too large: #{image_binary.bytesize} bytes (max #{max_size})"
        end

        # Validate magic bytes match declared type
        validate_image_magic_bytes!(image_binary, extension)

        # Create temp file with proper extension
        tempfile = Tempfile.new(["screenshot", ".#{extension}"])
        tempfile.binmode
        tempfile.write(image_binary)
        tempfile.rewind

        tempfile
      end

      def validate_image_magic_bytes!(data, expected_type)
        expected_magic = IMAGE_MAGIC_BYTES[expected_type]
        return unless expected_magic # Unknown type, skip validation

        # Special handling for WebP (RIFF....WEBP)
        if expected_type == "webp"
          unless data[0..3] == "RIFF".b && data[8..11] == "WEBP".b
            raise ScreenshotValidationError, "File content doesn't match declared type (expected WebP)"
          end
          return
        end

        unless data.byteslice(0, expected_magic.bytesize) == expected_magic
          raise ScreenshotValidationError, "File content doesn't match declared type (expected #{expected_type.upcase})"
        end
      end
    end
  end
end
