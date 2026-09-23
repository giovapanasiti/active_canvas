module ActiveCanvas
  class TemplateRenderer
    # Turns `data-ac-for="item in list"` and `data-ac-if="cond"` attributes
    # into the Liquid block tags around their element. Attributes survive every
    # HTML parser, so this is how the editor expresses loops and conditions
    # without text tags that tables and sanitizers would move. The loop goes
    # outside the condition. Text nodes inserted through the DOM are never
    # foster-parented, so a loop on a <tr> stays inside its <tbody>.
    class DirectiveExpander
      FOR_RE = /\A\s*[A-Za-z_][\w.]*\s+in\s+\S.*\z/m

      def initialize(source)
        @source = source.to_s
      end

      def expand
        return @source unless @source.include?("data-ac-for") || @source.include?("data-ac-if")

        fragment = Nokogiri::HTML5.fragment(@source)
        fragment.css("[data-ac-for], [data-ac-if]").each { |element| expand_element(element) }
        fragment.to_html
      end

      private

      def expand_element(element)
        loop_expr = element.remove_attribute("data-ac-for")&.value
        cond_expr = element.remove_attribute("data-ac-if")&.value

        # Siblings are inserted adjacent to the element, so the outer tag
        # (for) goes in first on the left and last on the right.
        if loop_expr
          raise Liquid::SyntaxError, "Invalid data-ac-for #{loop_expr.inspect}: expected \"item in list\"" unless loop_expr.match?(FOR_RE)
          element.add_previous_sibling(text("{% for #{loop_expr.strip} %}", element))
          element.add_next_sibling(text("{% endfor %}", element))
        end

        if cond_expr
          raise Liquid::SyntaxError, "Invalid data-ac-if: the condition is blank" if cond_expr.strip.empty?
          element.add_previous_sibling(text("{% if #{cond_expr.strip} %}", element))
          element.add_next_sibling(text("{% endif %}", element))
        end
      end

      def text(content, element)
        Nokogiri::XML::Text.new(content, element.document)
      end
    end
  end
end
