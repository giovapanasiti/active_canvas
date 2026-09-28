module ActiveCanvas
  # Applies an editor/API content update to a page: normalizes bindings,
  # optionally validates dynamic templates strictly before saving, clears
  # stale GrapesJS components when the caller doesn't manage them itself,
  # saves (letting Page's existing callback append a PageVersion), and
  # compiles Tailwind if needed. Shared by Admin::PagesController#save_editor
  # and the MCP `update_page_content`/`create_page`/`restore_page_version`
  # tools.
  #
  # `validate_template:` defaults to true (MCP relies on it to reject invalid
  # Liquid before saving). `save_editor` passes `validate_template: false`:
  # the editor autosaves every 60s with no client-side save gate, so it must
  # accept half-typed/invalid Liquid without blocking the save — the separate
  # `validate_template` endpoint is what the editor's own preview panel uses
  # to warn authors.
  class PageContentUpdate
    Result = Struct.new(:success?, :page, :errors, :template_error, :tailwind, keyword_init: true)

    ATTRIBUTE_KEYS = %i[content content_css content_js content_components template_enabled bindings].freeze

    def self.call(page, attrs, keep_components: false, validate_template: true)
      new(page, attrs, keep_components: keep_components, validate_template: validate_template).call
    end

    # Returns whatever the caller sent, parsed: nil for a blank/nil input,
    # the parsed Hash for a JSON string (raising JSON::ParserError on bad
    # JSON), or the value itself (unwrapped from ActionController::Parameters)
    # when it isn't a String. An already-Hash value (even {}) is a meaningful
    # "no bindings" and is passed through untouched, not collapsed to nil.
    def self.parse_bindings(raw)
      if raw.is_a?(String)
        return nil if raw.blank?
        JSON.parse(raw)
      elsif raw.nil?
        nil
      else
        raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
      end
    end

    def initialize(page, attrs, keep_components: false, validate_template: true)
      @page = page
      @attrs = ActiveSupport::HashWithIndifferentAccess.new(attrs.to_h).slice(*ATTRIBUTE_KEYS)
      @keep_components = keep_components
      @validate_template = validate_template
    end

    def call
      begin
        normalize_bindings!
      rescue JSON::ParserError => e
        return error_result([ "Bindings: #{e.message}" ])
      end

      if @validate_template && resulting_template_enabled?
        failure = template_validation_failure
        return failure if failure
      end

      apply_content_components_fallback!

      content_changed = @attrs.key?(:content) && @attrs[:content] != @page.content

      if @page.update(@attrs)
        tailwind = ActiveCanvas::TailwindCompilation.compile_if_needed(content_changed) do
          compiled_css = ActiveCanvas::TailwindCompiler.compile_for_page(@page)
          @page.update_columns(compiled_tailwind_css: compiled_css, tailwind_compiled_at: Time.current)
          compiled_css
        end

        Result.new(success?: true, page: @page, errors: [], template_error: nil, tailwind: tailwind)
      else
        error_result(@page.errors.full_messages)
      end
    end

    private

    def normalize_bindings!
      return unless @attrs.key?(:bindings)
      @attrs[:bindings] = self.class.parse_bindings(@attrs[:bindings])
    end

    def resulting_template_enabled?
      if @attrs.key?(:template_enabled)
        ActiveModel::Type::Boolean.new.cast(@attrs[:template_enabled])
      else
        @page.template_enabled?
      end
    end

    # Same strict check as Admin::PagesController#validate_template (and the MCP
    # `validate_template` tool), against the content/bindings the save is about to
    # apply -- including a collection template page's implicit item/items/collection/
    # pagination assigns (TemplateEditorContext), so a template that validates via
    # `validate_template` doesn't turn around and fail here on save/restore for the
    # same content.
    def template_validation_failure
      preview = @page.preview_with(
        content: @attrs[:content], content_css: @attrs[:content_css], content_js: @attrs[:content_js],
        bindings: @attrs[:bindings], template_enabled: true
      )

      if (message = ActiveCanvas::InvalidBindingsCheck.message_for(preview))
        return error_result([ message ])
      end

      context = preview.template? ? ActiveCanvas::TemplateEditorContext.live(preview) : {}
      ActiveCanvas::TemplateRenderer.new(preview, mode: :preview, context: context).render
      nil
    rescue ActiveCanvas::DataSources::TemplateRenderError => e
      Result.new(
        success?: false, page: @page, errors: [],
        template_error: { message: e.message, line: e.line, column: e.column }, tailwind: {}
      )
    end

    # When the caller doesn't manage content_components itself (MCP always)
    # and content is changing, clear it so the GrapesJS editor rebuilds from
    # content on next open (existing fallback in editor.js).
    def apply_content_components_fallback!
      return if @keep_components
      return unless @attrs.key?(:content)
      return if @attrs.key?(:content_components)
      return if @attrs[:content] == @page.content

      @attrs[:content_components] = nil
    end

    def error_result(errors)
      Result.new(success?: false, page: @page, errors: errors, template_error: nil, tailwind: {})
    end
  end
end
