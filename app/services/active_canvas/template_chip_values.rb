module ActiveCanvas
  # Live values for the editor's chips: what each {{ }} shows in its first
  # occurrence and how many items each loop renders. Shared by
  # Admin::PagesController#chip_values and the `preview_template_values` MCP
  # tool.
  class TemplateChipValues
    Result = Struct.new(:body, :invalid_bindings?, keyword_init: true)

    def self.call(page, content:, bindings:, context: {})
      preview = page.preview_with(bindings: bindings, template_enabled: true)

      if (message = InvalidBindingsCheck.message_for(preview))
        return Result.new(body: { values: {}, loops: {}, error: message }, invalid_bindings?: true)
      end

      Result.new(body: TemplateRenderer.new(preview, mode: :preview, context: context).chip_values(content), invalid_bindings?: false)
    end
  end
end
