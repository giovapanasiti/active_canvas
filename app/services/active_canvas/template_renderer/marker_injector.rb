require "cgi"

module ActiveCanvas
  class TemplateRenderer
    # Preprocesses a Liquid source so that each output expression and each
    # control-flow block is wrapped in a marker <span>. The wrapped result is
    # then handed to Liquid::Template.parse — the spans are pass-through HTML,
    # and the Liquid tags inside still render normally.
    #
    # v1 scope: top-level `{% for %}...{% endfor %}` and `{% if %}...{% endif %}`
    # blocks; nested blocks are NOT chip-wrapped (the outer block is wrapped
    # and the nested content renders normally inside it).
    class MarkerInjector
      VAR_RE   = /\{\{\s*(.+?)\s*\}\}/
      BLOCK_RE = /\{%\s*(for|if)\s+([^%]+?)\s*%\}(.*?)\{%\s*end\1\s*%\}/m

      def initialize(source)
        @source = source.to_s
      end

      def inject
        with_attribute_protection do |text|
          text = wrap_blocks(text)
          wrap_vars(text)
        end
      end

      private

      def wrap_vars(text)
        text.gsub(VAR_RE) do
          expr = Regexp.last_match(1)
          original = Regexp.last_match(0)
          %(<span data-ac-var="#{h(expr)}" data-ac-source="#{h(original)}" class="ac-chip">#{original}</span>)
        end
      end

      def wrap_blocks(text)
        text.gsub(BLOCK_RE) do
          tag, expr, body = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
          original = Regexp.last_match(0)
          inner    = wrap_vars(body)
          %(<span data-ac-block="#{h("#{tag} #{expr}")}" data-ac-source="#{h(original)}" class="ac-block">{% #{tag} #{expr} %}#{inner}{% end#{tag} %}</span>)
        end
      end

      # Don't inject markers inside HTML attribute values (would produce invalid
      # HTML like `<a href="<span ...>...</span>">`). Strategy: pull out
      # attribute regions, substitute, then restore.
      ATTR_RE = /(\s\w+(?:[-:]\w+)*\s*=\s*)("([^"]*)"|'([^']*)')/

      def with_attribute_protection
        protected_regions = []
        scrubbed = @source.gsub(ATTR_RE) do
          full = Regexp.last_match(0)
          token = "\x00ACATTR#{protected_regions.size}\x00"
          protected_regions << full
          token
        end
        result = yield(scrubbed)
        protected_regions.each_with_index do |val, idx|
          result = result.sub("\x00ACATTR#{idx}\x00", val)
        end
        result
      end

      def h(str)
        CGI.escapeHTML(str.to_s)
      end
    end
  end
end
