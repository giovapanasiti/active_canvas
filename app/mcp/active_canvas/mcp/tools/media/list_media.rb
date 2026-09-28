module ActiveCanvas
  module Mcp
    module Tools
      module Media
        class ListMedia < BaseTool
          tool_name "list_media"
          description "List uploaded media. images_only (default true) restricts to the configured allowed content types; pass false to see every uploaded file."
          input_schema(properties: {
            limit: { type: "integer" },
            offset: { type: "integer" },
            images_only: { type: "boolean" }
          })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            images_only = args.key?(:images_only) ? ActiveModel::Type::Boolean.new.cast(args[:images_only]) : true
            relation = (images_only ? ActiveCanvas::Media.images : ActiveCanvas::Media.all).recent

            page = paginate(relation, args)
            page.merge(items: page[:items].map { |m| Serializers.media(m) })
          end
        end
      end
    end
  end
end
