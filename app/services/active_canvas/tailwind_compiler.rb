require "open3"

module ActiveCanvas
  class TailwindCompiler
    class CompilationError < StandardError; end

    LOG_PREFIX = "[ActiveCanvas::TailwindCompiler]".freeze

    class << self
      def compile_for_page(page)
        log_info "Starting compilation for page ##{page.id} (#{page.title})"
        start_time = Time.current

        unless available?
          log_error "tailwindcss-ruby gem is not installed"
          raise CompilationError, "tailwindcss-ruby gem is not installed"
        end

        html_content = page.content.to_s
        if html_content.blank?
          log_info "Page ##{page.id} has no content, skipping compilation"
          return ""
        end

        log_debug "Content size: #{html_content.bytesize} bytes"

        Dir.mktmpdir("active_canvas_tailwind") do |dir|
          log_debug "Created temp directory: #{dir}"

          html_file = File.join(dir, "input.html")
          css_file = File.join(dir, "output.css")

          File.write(html_file, html_content)
          log_debug "Wrote HTML content to #{html_file}"

          compiled_css = compile_css(html_file, css_file, page.id)

          elapsed = ((Time.current - start_time) * 1000).round(2)
          log_info "Compilation completed for page ##{page.id} in #{elapsed}ms (output: #{compiled_css.bytesize} bytes)"

          compiled_css
        end
      end

      def available?
        # Always check fresh - no caching
        defined?(Tailwindcss::Ruby) && Tailwindcss::Ruby.respond_to?(:executable)
      end

      def clear_availability_cache!
        # No longer caches, but keep method for compatibility
      end

      private

      def compile_css(html_file, css_file, page_id)
        executable = Tailwindcss::Ruby.executable
        log_debug "Using Tailwind executable: #{executable}"

        # For Tailwind v4, we need to use an input CSS file with @source directive
        # instead of the --content CLI flag
        input_css_file = File.join(File.dirname(html_file), "input.css")

        # Tailwind 4.x uses @import "tailwindcss" with source() function
        # or @source directive to specify content paths
        input_css = <<~CSS
          @import "tailwindcss";
          @source "#{html_file}";
        CSS

        File.write(input_css_file, input_css)
        log_debug "Input CSS with @source: #{input_css.strip}"

        command = [
          executable,
          "--input", input_css_file,
          "--output", css_file,
          "--minify"
        ]

        log_debug "Running command: #{command.join(' ')}"

        compile_start = Time.current
        stdout, stderr, status = Open3.capture3(*command)
        compile_elapsed = ((Time.current - compile_start) * 1000).round(2)

        log_debug "Tailwind CLI execution took #{compile_elapsed}ms"

        if stdout.present?
          log_debug "Tailwind stdout: #{stdout.truncate(500)}"
        end

        unless status.success?
          log_error "Compilation failed for page ##{page_id} (exit code: #{status.exitstatus})"
          log_error "Tailwind stderr: #{stderr}"
          raise CompilationError, "Tailwind compilation failed: #{stderr}"
        end

        if stderr.present? && !stderr.strip.empty?
          log_warn "Tailwind warnings for page ##{page_id}: #{stderr.truncate(500)}"
        end

        unless File.exist?(css_file)
          log_error "Output file not created for page ##{page_id}"
          raise CompilationError, "Tailwind output file was not created"
        end

        css_content = File.read(css_file)
        log_debug "Read #{css_content.bytesize} bytes from output file"

        css_content
      end

      def log_info(message)
        Rails.logger.info "#{LOG_PREFIX} #{message}"
      end

      def log_debug(message)
        Rails.logger.debug "#{LOG_PREFIX} #{message}"
      end

      def log_warn(message)
        Rails.logger.warn "#{LOG_PREFIX} #{message}"
      end

      def log_error(message)
        Rails.logger.error "#{LOG_PREFIX} #{message}"
      end
    end
  end
end
