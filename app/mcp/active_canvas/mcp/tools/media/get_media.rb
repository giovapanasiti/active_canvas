module ActiveCanvas
  module Mcp
    module Tools
      module Media
        class GetMedia < BaseTool
          tool_name "get_media"
          description "Fetch a single media record by id, including its full metadata."
          input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            media = ActiveCanvas::Media.find(args[:id])
            Serializers.media(media).merge(metadata: media.metadata)
          end
        end
      end
    end
  end
end
