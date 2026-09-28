module ActiveCanvas
  module Admin
    module ApplicationHelper
      # Collections opted into the sidebar (Collection#show_in_sidebar), for
      # the "Content" nav section. Ordered by name. Memoized: the layout and
      # collections_nav_active? both read it, so it's one query per request.
      def sidebar_collections
        @sidebar_collections ||= ActiveCanvas::Collection.in_sidebar.order(:name).to_a
      end

      def sidebar_collection_active?(collection)
        controller_name == "collection_items" && params[:collection_id].to_s == collection.id.to_s
      end

      # The generic "Collections" nav link: active on the collections list/form,
      # and on a collection's items page too — unless that collection already
      # has its own highlighted link in the sidebar (show_in_sidebar), in which
      # case only that specific link should be marked active.
      def collections_nav_active?
        return true if controller_name == "collections"
        return false unless controller_name == "collection_items"

        sidebar_collections.none? { |collection| sidebar_collection_active?(collection) }
      end
    end
  end
end
