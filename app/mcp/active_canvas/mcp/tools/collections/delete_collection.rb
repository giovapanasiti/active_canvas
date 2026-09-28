module ActiveCanvas
  module Mcp
    module Tools
      module Collections
        class DeleteCollection < BaseTool
          tool_name "delete_collection"
          description "Delete a collection and all its items. Requires the 'publish' scope in addition to 'write' when any item is published."
          input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])
          annotations(destructive_hint: true)
          required_scope :write

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:id])
            if collection.items.published.exists?
              require_scope!(:publish, "This collection has published items; deleting it requires the 'publish' scope.")
            end

            collection.destroy!
            { deleted: true, id: collection.id }
          end
        end
      end
    end
  end
end
