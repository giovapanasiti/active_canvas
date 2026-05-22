require "cgi"
require "securerandom"

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

      # Matches HTML attribute pairs like `class="foo"` or `data-x='bar'`.
      # Used to shield attribute values from {{ }} / {% %} rewriting.
      ATTR_RE = /(\s\w+(?:[-:]\w+)*\s*=\s*)("([^"]*)"|'([^']*)')/

      def initialize(source)
        @source = source.to_s
      end

      def inject
        # Pass 1: shield the source's existing HTML attribute values, wrap
        # block-level Liquid tags. wrap_blocks emits chips whose own attributes
        # contain literal {{ }} — those must be shielded before wrap_vars runs.
        text = with_attribute_protection(@source) { |t| wrap_blocks(t) }
        # Pass 2: shield ALL attribute values (including the freshly-emitted
        # chip attributes from pass 1) so wrap_vars only wraps {{ }} in text.
        with_attribute_protection(text) { |t| wrap_vars(t) }
      end

      private

      def wrap_vars(text)
        text.gsub(VAR_RE) do
          expr = Regexp.last_match(1)
          original = Regexp.last_match(0)
          %(<span data-ac-var="#{h(expr)}" data-ac-source="#{protect(original)}" class="ac-chip">#{original}</span>)
        end
      end

      def wrap_blocks(text)
        text.gsub(BLOCK_RE) do
          tag, expr, body = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
          original = Regexp.last_match(0)
          %(<span data-ac-block="#{h("#{tag} #{expr}")}" data-ac-source="#{protect(original)}" class="ac-block">{% #{tag} #{expr} %}#{body}{% end#{tag} %}</span>)
        end
      end

      # Wrap the literal source in {% raw %} so Liquid leaves it untouched,
      # then HTML-escape so the attribute stays well-formed. After Liquid
      # renders, the {% raw %} markers are stripped and the attribute holds
      # the original (HTML-escaped) source for the editor to round-trip.
      def protect(source)
        "{% raw %}#{h(source)}{% endraw %}"
      end

      # Pull attribute regions out of `source`, yield the scrubbed text for
      # rewriting, then restore. Uses a random token per region so nested
      # invocations (pass 1 + pass 2) can't collide on placeholder names.
      def with_attribute_protection(source)
        regions = []
        scrubbed = source.gsub(ATTR_RE) do
          token = "\x00ACATTR#{SecureRandom.hex(8)}\x00"
          regions << [token, Regexp.last_match(0)]
          token
        end
        result = yield(scrubbed)
        regions.each { |token, val| result = result.sub(token, val) }
        result
      end

      def h(str)
        CGI.escapeHTML(str.to_s)
      end
    end
  end
end
