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
          Generate clean, semantic HTML using #{framework_name(framework)}.

          Guidelines:
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
          Convert this screenshot into clean HTML using #{framework_name(framework)}.

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

      def framework_name(framework)
        case framework.to_s
        when "tailwind" then "Tailwind CSS classes"
        when "bootstrap5" then "Bootstrap 5 classes"
        else "vanilla CSS with inline styles"
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
        tempfile = Tempfile.new([ "screenshot", ".#{extension}" ])
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
