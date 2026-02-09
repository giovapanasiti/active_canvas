module ActiveCanvas
  module TailwindCompilation
    extend ActiveSupport::Concern

    private

    # Compiles Tailwind CSS if the framework is active and content changed.
    # Callers must pass a block that performs the actual compilation and
    # persistence, and returns the compiled CSS string.
    #
    #   compile_tailwind_if_needed(content_changed) do
    #     css = ActiveCanvas::TailwindCompiler.compile_for_page(@page)
    #     @page.update_columns(compiled_tailwind_css: css, tailwind_compiled_at: Time.current)
    #     css
    #   end
    #
    def compile_tailwind_if_needed(content_changed)
      return { compiled: false, reason: "content_unchanged" } unless content_changed
      return { compiled: false, reason: "not_tailwind" } unless Setting.css_framework == "tailwind"
      return { compiled: false, reason: "gem_not_available" } unless ActiveCanvas::TailwindCompiler.available?

      begin
        start_time = Time.current
        compiled_css = yield
        elapsed_ms = ((Time.current - start_time) * 1000).round

        {
          compiled: true,
          success: true,
          css_size: compiled_css.bytesize,
          elapsed_ms: elapsed_ms
        }
      rescue ActiveCanvas::TailwindCompiler::CompilationError => e
        Rails.logger.error "[ActiveCanvas] Tailwind compilation failed: #{e.message}"
        { compiled: true, success: false, error: e.message }
      end
    end
  end
end
