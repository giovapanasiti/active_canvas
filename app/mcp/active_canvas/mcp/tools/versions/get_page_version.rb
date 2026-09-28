module ActiveCanvas
  module Mcp
    module Tools
      module Versions
        class GetPageVersion < BaseTool
          tool_name "get_page_version"
          description "Get one page version's full before/after content, CSS, bindings and a unified content_diff."
          input_schema(properties: { page_id: { type: "integer" }, version_number: { type: "integer" } }, required: [ "page_id", "version_number" ])
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = ActiveCanvas::Page.find(args[:page_id])
            version = page.versions.find_by!(version_number: args[:version_number])
            Serializers.page_version(version)
          end
        end
      end
    end
  end
end
