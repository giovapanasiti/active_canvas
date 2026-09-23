require "cgi"

module ActiveCanvas
  class TemplateRenderer
    MODES = %i[public preview].freeze
    PUBLIC_FALLBACK = "<!-- dynamic block unavailable -->".freeze

    def initialize(page, mode:)
      raise ArgumentError, "mode must be one of #{MODES.inspect}" unless MODES.include?(mode)
      @page = page
      @mode = mode
    end

    def render
      return @page.content.to_s unless @page.template_enabled?
      render_dynamic
    rescue StandardError => e
      handle_error(e)
    end

    private

    def preview?
      @mode == :preview
    end

    # Preview is strict so authors see every mistake. Public is forgiving: an
    # undefined variable, an unknown filter or a node that raises renders empty
    # and the rest of the page survives; only syntax errors, resource limits
    # and failures before rendering fall back to the comment. The canvas never
    # holds rendered output, so there is nothing to undo here.
    def render_dynamic
      source = DirectiveExpander.new(@page.content.to_s).expand
      source = decode_entities_in_liquid_tags(source)

      assigns  = BindingResolver.new(@page.bindings, silent_errors: !preview?).resolve
      template = Liquid::Template.parse(source, error_mode: :strict, line_numbers: true)
      template.resource_limits.render_length_limit = ActiveCanvas.config.template_render_length_limit
      template.resource_limits.render_score_limit  = ActiveCanvas.config.template_render_score_limit
      template.resource_limits.assign_score_limit  = ActiveCanvas.config.template_assign_score_limit
      rendered = if preview?
        template.render!(assigns, strict_variables: true, strict_filters: true)
      else
        template.render(assigns, exception_renderer: method(:render_node_error))
      end
      ContentSanitizer.sanitize_html(rendered)
    end

    # WYSIWYG editors (GrapeJS) encode `<`, `>`, `&`, `"` as HTML entities when
    # serializing text nodes, including inside Liquid tags the user typed. So
    # `{% if a > b %}` becomes `{% if a &gt; b %}` after editor round-trip,
    # which Liquid rejects with a syntax error. Decode entities inside tags
    # before parsing so user-authored Liquid keeps working.
    def decode_entities_in_liquid_tags(source)
      source.gsub(/\{\{.+?\}\}|\{%.+?%\}/m) do |tag|
        CGI.unescapeHTML(tag)
      end
    end

    def handle_error(error)
      if preview?
        raise DataSources::TemplateRenderError.new(
          error.message,
          line: error.try(:line_number),
          column: error.try(:column),
          original: error
        )
      end

      Rails.error.report(error, handled: true, source: "active_canvas", context: { page_id: @page.id })
      Rails.logger.warn("[ActiveCanvas] dynamic page #{@page.id} render failed: #{error.class}: #{error.message}")
      PUBLIC_FALLBACK
    end

    # Public mode: a single broken node renders empty and is reported; only a
    # resource limit stops the whole render (re-raised so `render` falls back).
    def render_node_error(error)
      raise error if error.is_a?(Liquid::MemoryError)
      Rails.error.report(error, handled: true, source: "active_canvas", context: { page_id: @page.id })
      Rails.logger.warn("[ActiveCanvas] dynamic page #{@page.id} node failed: #{error.class}: #{error.message}")
      ""
    end
  end
end
