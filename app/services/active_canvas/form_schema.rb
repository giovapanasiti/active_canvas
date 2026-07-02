module ActiveCanvas
  # Derives a form's definition from a page's saved content. The markup IS the
  # definition: only fields present in the authored <form> are accepted, and
  # `required` attributes drive validation. Shared key derivation keeps the
  # stamper and the endpoint pointing at the same form.
  class FormSchema
    INTERNAL_PREFIX = "ac_".freeze
    EXCLUDED_TYPES = %w[file submit button image reset].freeze

    Schema = Struct.new(:fields, :required)

    class << self
      def forms(html)
        Nokogiri::HTML5.fragment(html.to_s).css("form").each_with_index.map do |form, index|
          [ key_for(form, index), form ]
        end
      end

      def keys(html)
        forms(html).map(&:first)
      end

      def derive(html, form_key)
        _, form = forms(html).find { |key, _| key == form_key }
        return nil unless form

        controls = form.css("input, select, textarea").select { |node| accepted?(node) }
        Schema.new(
          controls.map { |node| node["name"] }.uniq,
          controls.select { |node| node.has_attribute?("required") }.map { |node| node["name"] }.uniq
        )
      end

      def key_for(form, index)
        form["name"].presence || form["id"].presence || "form-#{index + 1}"
      end

      private

      def accepted?(node)
        name = node["name"]
        name.present? &&
          !name.start_with?(INTERNAL_PREFIX) &&
          !EXCLUDED_TYPES.include?(node["type"].to_s.downcase)
      end
    end
  end
end
