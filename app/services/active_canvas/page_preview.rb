module ActiveCanvas
  # Renders a complete HTML page (layout, partials, CSS framework) from
  # possibly-unsaved content/css/js/bindings, without needing a real request.
  # Used by Admin::PagesController#preview_iframe and the
  # `render_page_preview` MCP tool.
  class PagePreview
    def self.call(page, content: nil, content_css: nil, content_js: nil, bindings: nil, template_enabled: nil)
      new(page, content: content, content_css: content_css, content_js: content_js,
                bindings: bindings, template_enabled: template_enabled).call
    end

    def initialize(page, content: nil, content_css: nil, content_js: nil, bindings: nil, template_enabled: nil)
      @page = page
      @content = content
      @content_css = content_css
      @content_js = content_js
      @bindings = bindings
      @template_enabled = template_enabled
    end

    def call
      preview = @page.preview_with(
        content: @content, content_css: @content_css, content_js: @content_js,
        bindings: @bindings, template_enabled: @template_enabled
      )

      if (message = ActiveCanvas::InvalidBindingsCheck.message_for(preview))
        return { html: nil, error: { message: message } }
      end

      html = ActiveCanvas::PagesController.renderer.render(
        template: "active_canvas/pages/show",
        layout: "active_canvas/application",
        formats: [ :html ],
        assigns: { page: preview }
      )

      { html: html, error: nil }
    end
  end
end
