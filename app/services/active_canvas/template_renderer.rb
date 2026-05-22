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
    rescue Liquid::Error, DataSources::Error => e
      handle_error(e)
    end

    private

    def render_dynamic
      source = @page.content.to_s
      source = decode_entities_in_liquid_tags(source)
      source = MarkerInjector.new(source).inject if @mode == :preview

      assigns  = BindingResolver.new(@page.bindings).resolve
      template = Liquid::Template.parse(source, error_mode: :strict)
      template.resource_limits.render_length_limit = ActiveCanvas.config.template_render_length_limit
      template.resource_limits.render_score_limit  = ActiveCanvas.config.template_render_score_limit
      template.resource_limits.assign_score_limit  = ActiveCanvas.config.template_assign_score_limit
      rendered = template.render!(assigns, strict_variables: true, strict_filters: true)
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
      case @mode
      when :preview
        raise DataSources::TemplateRenderError.new(
          error.message,
          line: error.try(:line_number),
          column: error.try(:column),
          original: error
        )
      when :public
        Rails.logger.warn("[ActiveCanvas] dynamic page #{@page.id} render failed: #{error.class}: #{error.message}")
        PUBLIC_FALLBACK
      end
    end
  end
end
