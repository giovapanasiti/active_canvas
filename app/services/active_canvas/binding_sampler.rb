module ActiveCanvas
  # First rows of one binding, resolved from the caller's (possibly unsaved)
  # bindings, so an author/agent can see which field names exist before
  # typing {{ }}. Shared by Admin::PagesController#sample_data and the
  # `sample_binding_data` MCP tool.
  class BindingSampler
    Result = Struct.new(:rows, :error, :not_found, keyword_init: true)

    def self.call(page, bindings:, binding:, rows: 3)
      preview = page.preview_with(bindings: bindings)

      if (message = InvalidBindingsCheck.message_for(preview))
        return Result.new(rows: nil, error: message, not_found: false)
      end

      name = binding.to_s
      unless preview.bindings.key?(name)
        return Result.new(rows: nil, error: "No binding named #{name.inspect}", not_found: true)
      end

      sampled = TemplateRenderer::BindingResolver.new(preview.bindings).sample(name, rows: rows)
      Result.new(rows: sampled, error: nil, not_found: false)
    rescue StandardError => e
      Rails.logger.warn("[ActiveCanvas] sample_data for page #{page.id} failed: #{e.class}: #{e.message}")
      message = Rails.env.development? ? e.message : "#{e.class}: the data source failed"
      Result.new(rows: nil, error: message, not_found: false)
    end
  end
end
