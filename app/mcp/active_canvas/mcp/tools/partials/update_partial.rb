module ActiveCanvas
  module Mcp
    module Tools
      module Partials
        class UpdatePartial < BaseTool
          CONTENT_KEYS = %i[name active content content_css content_js].freeze

          tool_name "update_partial"
          description "Update a partial's name, active flag, content, content_css and/or content_js. Requires the 'publish' scope. When content changes, content_components is cleared; Tailwind CSS is recompiled by the model's own callback."
          input_schema(
            properties: {
              id: { type: "integer" },
              name: { type: "string" },
              active: { type: "boolean" },
              content: { type: "string" },
              content_css: { type: "string" },
              content_js: { type: "string" }
            },
            required: [ "id" ]
          )
          required_scope :publish

          def perform(args)
            partial = ActiveCanvas::Partial.find(args[:id])
            attrs = args.slice(*CONTENT_KEYS).to_h

            attrs["content_components"] = nil if attrs.key?("content") && attrs["content"] != partial.content

            partial.update!(attrs)
            Serializers.partial(partial)
          end
        end
      end
    end
  end
end
