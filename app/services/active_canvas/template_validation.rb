module ActiveCanvas
  # Runs the editor's current source through the strict preview renderer and
  # reports the first error with its position; never renders HTML. Shared by
  # Admin::PagesController#validate_template and the `validate_template` MCP
  # tool.
  class TemplateValidation
    def self.call(page, content:, bindings:)
      preview = page.preview_with(content: content, bindings: bindings, template_enabled: true)

      if (message = InvalidBindingsCheck.message_for(preview))
        return { ok: false, error: { message: message, line: nil, column: nil } }
      end

      TemplateRenderer.new(preview, mode: :preview).render
      { ok: true, error: nil }
    rescue ActiveCanvas::DataSources::TemplateRenderError => e
      { ok: false, error: { message: e.message, line: e.line, column: e.column } }
    end
  end
end
