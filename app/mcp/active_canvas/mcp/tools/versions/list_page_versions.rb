module ActiveCanvas
  module Mcp
    module Tools
      module Versions
        class ListPageVersions < BaseTool
          tool_name "list_page_versions"
          description "List a page's version history, newest first: version_number, changed_by, change_summary, timestamps, and content sizes before/after. Call get_page_version for the full before/after content and diff of one version."
          input_schema(properties: { page_id: { type: "integer" }, limit: { type: "integer" }, offset: { type: "integer" } }, required: [ "page_id" ])
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = ActiveCanvas::Page.find(args[:page_id])
            result = paginate(page.versions.recent, args)
            result.merge(items: result[:items].map { |v| Serializers.page_version_summary(v) })
          end
        end
      end
    end
  end
end
