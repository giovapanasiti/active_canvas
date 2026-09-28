module ActiveCanvas
  module Mcp
    module Tools
      module Media
        class DeleteMedia < BaseTool
          tool_name "delete_media"
          description "Delete a media record and its attached file."
          input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])
          annotations(destructive_hint: true)
          required_scope :write

          def perform(args)
            media = ActiveCanvas::Media.find(args[:id])
            media.destroy!
            { deleted: true, id: media.id }
          end
        end
      end
    end
  end
end
