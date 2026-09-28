module ActiveCanvas
  module Mcp
    module Tools
      module Pages
        class DeletePage < BaseTool
          tool_name "delete_page"
          description "Delete a page permanently, including its version history. Requires the 'publish' scope in addition to 'write' when the page is currently published. Refuses to delete the current homepage regardless of scope. Refuses to delete a template page directly; it is removed with its collection."
          input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])
          annotations(destructive_hint: true)
          required_scope :write

          def perform(args)
            page = ActiveCanvas::Page.find(args[:id])

            fail!("Template pages are removed with their collection") if page.template?

            if ActiveCanvas::Setting.homepage_page_id == page.id
              fail!("This page is the homepage; choose another homepage first.")
            end

            require_publish_if_published!(page, "page")
            page.destroy!
            { deleted: true, id: page.id }
          end
        end
      end
    end
  end
end
