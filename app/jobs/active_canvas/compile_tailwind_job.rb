module ActiveCanvas
  class CompileTailwindJob < ApplicationJob
    queue_as :default

    retry_on TailwindCompiler::CompilationError, wait: :polynomially_longer, attempts: 3

    LOG_PREFIX = "[ActiveCanvas::CompileTailwindJob]".freeze

    def perform(page_id)
      log_info "Job started for page ##{page_id}"

      page = Page.find_by(id: page_id)
      unless page
        log_warn "Page ##{page_id} not found, skipping"
        return
      end

      unless TailwindCompiler.available?
        log_info "Skipping: tailwindcss-ruby gem not available"
        return
      end

      unless Setting.css_framework == "tailwind"
        log_info "Skipping: Tailwind not selected as framework (current: #{Setting.css_framework})"
        return
      end

      log_info "Compiling Tailwind CSS for page ##{page.id} (#{page.title})"
      start_time = Time.current

      compiled_css = TailwindCompiler.compile_for_page(page)

      page.update_columns(
        compiled_tailwind_css: compiled_css,
        tailwind_compiled_at: Time.current
      )

      elapsed = ((Time.current - start_time) * 1000).round(2)
      log_info "Job completed for page ##{page.id} in #{elapsed}ms (CSS size: #{compiled_css.bytesize} bytes)"

    rescue TailwindCompiler::CompilationError => e
      log_error "Compilation failed for page ##{page_id}: #{e.message}"
      raise
    rescue => e
      log_error "Unexpected error for page ##{page_id}: #{e.class.name}: #{e.message}"
      log_error e.backtrace.first(5).join("\n")
      raise
    end

    private

    def log_info(message)
      Rails.logger.info "#{LOG_PREFIX} #{message}"
    end

    def log_warn(message)
      Rails.logger.warn "#{LOG_PREFIX} #{message}"
    end

    def log_error(message)
      Rails.logger.error "#{LOG_PREFIX} #{message}"
    end
  end
end
