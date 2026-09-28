module ActiveCanvas
  # Renders a collection item's *show* template page with the item's DRAFT
  # data, outside of a real request (a bare ActionController::Renderer, the
  # same approach PagePreview uses for regular pages). Shared by
  # Admin::CollectionItemsController#preview and the `preview_collection_item`
  # MCP tool, so a draft item previews identically from either caller.
  class CollectionItemPreview
    def self.call(item)
      new(item).call
    end

    def initialize(item)
      @item = item
      @collection = item.collection
    end

    # Raises ActiveRecord::RecordNotFound (via find_by!) when the collection
    # has no show template page -- callers let that propagate as their usual
    # "not found" error rather than a preview-specific error shape.
    def call
      page = @collection.template_pages.find_by!(collection_role: "show")

      html = RequestScopedRenderer.build.render(
        template: "active_canvas/collection_pages/show",
        layout: "active_canvas/application",
        formats: [ :html ],
        assigns: {
          page: page,
          context: ActiveCanvas::CollectionPageContext.show(@item, data: :draft),
          head_seo: ActiveCanvas::CollectionSource.new(@collection).head_seo(@item, data: :draft),
          robots: "noindex"
        }
      )

      { html: html }
    end
  end
end
