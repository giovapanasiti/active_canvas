module ActiveCanvas
  module Mcp
    module Tools
      module DynamicData
        class ListDataSources < BaseTool
          tool_name "list_data_sources"
          description "List every binding source the editor's Data panel can offer: the literal pseudo-source, registered data sources, and collections with their fields."
          input_schema(properties: {})
          annotations(read_only_hint: true)
          required_scope :read

          def perform(_args)
            ActiveCanvas::DataSourceCatalog.call
          end
        end
      end
    end
  end
end
