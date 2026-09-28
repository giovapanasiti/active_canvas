require "cgi"

module ActiveCanvas
  class TemplateRenderer
    MODES = %i[public preview].freeze
    PUBLIC_FALLBACK = "<!-- dynamic block unavailable -->".freeze

    # `context:` is extra Liquid assigns merged **over** the page's resolved
    # bindings (Part 4 "Implicit assigns") — used to give a collection's
    # template pages their `item`/`items`/`collection`/`pagination` names
    # (CollectionPageContext). A binding sharing one of those names is
    # shadowed: context always wins.
    def initialize(page, mode:, context: {})
      raise ArgumentError, "mode must be one of #{MODES.inspect}" unless MODES.include?(mode)
      @page = page
      @mode = mode
      @context = (context || {}).transform_keys(&:to_s)
    end

    def render
      return @page.content.to_s unless @page.template_enabled?
      render_dynamic
    rescue StandardError => e
      handle_error(e)
    end

    MAX_LOOP_COPIES = 10

    # What the editor's live-data view needs: the text each chip displays in
    # its first occurrence, and for every loop and condition element (in
    # document order) how it rendered: the item count, the rendered copies
    # after the first (so the editor can show them as ghosts), and whether a
    # condition holds. Nested elements are measured inside the first copy of
    # their enclosing loop. Lenient render; only text and rendered HTML that
    # the editor treats as display-only leave this method.
    def chip_values(decorated_html)
      source, markers = mark_for_probe(decorated_html)
      source = DirectiveExpander.new(source).expand
      source = decode_entities_in_liquid_tags(source)

      assigns  = BindingResolver.new(@page.bindings, silent_errors: true).resolve.merge(@context)
      template = Liquid::Template.parse(source, error_mode: :strict, line_numbers: true)
      template.resource_limits.render_length_limit = ActiveCanvas.config.template_render_length_limit
      template.resource_limits.render_score_limit  = ActiveCanvas.config.template_render_score_limit
      template.resource_limits.assign_score_limit  = ActiveCanvas.config.template_assign_score_limit
      rendered = template.render(assigns, exception_renderer: ->(e) { raise e if e.is_a?(Liquid::MemoryError); "" })

      fragment = Nokogiri::HTML5.fragment(rendered)
      values = fragment.css("[data-ac-id]").each_with_object({}) do |chip, acc|
        acc[chip["data-ac-id"]] ||= chip.text.strip.truncate(200)
      end
      loops = markers[:loops].map do |marker|
        copies = occurrences(fragment, marker)
        { expr: marker[:expr], count: copies.size, copies: copies.drop(1).first(MAX_LOOP_COPIES).map { |c| strip_probe_markers(c).to_html } }
      end
      conds = markers[:conds].map { |marker| { expr: marker[:expr], shown: occurrences(fragment, marker).any? } }
      { values: values, loops: loops, conds: conds }
    rescue StandardError => e
      { values: {}, loops: [], conds: [], error: e.message }
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

      assigns  = BindingResolver.new(@page.bindings, silent_errors: !preview?).resolve.merge(@context)
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

    # Chips render their source (their text may hold a stale value in the
    # editor). Loop and condition elements get a marker attribute with a
    # document-order id and remember their nearest enclosing loop, so their
    # copies can be found and scoped after the Liquid tags are consumed.
    def mark_for_probe(html)
      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css("[data-ac-id]").each { |chip| chip.content = chip["data-ac-source"] if chip["data-ac-source"] }

      markers = { loops: [], conds: [] }
      fragment.css("[data-ac-for], [data-ac-if]").each_with_index do |el, i|
        parent = el.ancestors.find { |a| a["data-ac-probe-loop"] }
        parent_loop = parent && parent["data-ac-probe-loop"]
        if el["data-ac-for"]
          el["data-ac-probe-loop"] = "l#{i}"
          markers[:loops] << { id: "l#{i}", attr: "data-ac-probe-loop", expr: el["data-ac-for"], parent: parent_loop }
        end
        if el["data-ac-if"]
          el["data-ac-probe-cond"] = "k#{i}"
          markers[:conds] << { id: "k#{i}", attr: "data-ac-probe-cond", expr: el["data-ac-if"], parent: parent_loop }
        end
      end
      [ fragment.to_html, markers ]
    end

    # The rendered copies of a marked element, inside the first copy of its
    # enclosing loop (the whole page when it is not nested).
    def occurrences(fragment, marker)
      scope = marker[:parent] ? fragment.at_css("[data-ac-probe-loop=\"#{marker[:parent]}\"]") : fragment
      return [] unless scope
      scope.css("[#{marker[:attr]}=\"#{marker[:id]}\"]").to_a
    end

    def strip_probe_markers(element)
      copy = element.dup
      ([ copy ] + copy.css("[data-ac-probe-loop], [data-ac-probe-cond]").to_a).each do |el|
        el.remove_attribute("data-ac-probe-loop")
        el.remove_attribute("data-ac-probe-cond")
      end
      copy
    end
  end
end
