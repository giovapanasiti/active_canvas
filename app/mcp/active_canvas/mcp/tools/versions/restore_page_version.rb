module ActiveCanvas
  module Mcp
    module Tools
      module Versions
        class RestorePageVersion < BaseTool
          tool_name "restore_page_version"
          description "Restore a page's content, CSS and bindings to an earlier version's saved values. content_js and template_enabled are not versioned and are not touched by this. History is append-only: this creates a new version rather than deleting later ones. Requires the 'publish' scope in addition to 'write' when the page is currently published."
          input_schema(properties: { page_id: { type: "integer" }, version_number: { type: "integer" } }, required: [ "page_id", "version_number" ])
          annotations(destructive_hint: true)
          required_scope :write

          def perform(args)
            page = ActiveCanvas::Page.find(args[:page_id])
            require_publish_if_published!(page, "page")

            version = page.versions.find_by!(version_number: args[:version_number])
            result = page.restore_version!(version)
            fail!(content_update_error(result)) unless result.success?

            { page: Serializers.page(page.reload), version_number: page.current_version_number }
          end
        end
      end
    end
  end
end
