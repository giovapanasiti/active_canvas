module ActiveCanvas
  module Admin
    class CollectionItemsController < ApplicationController
      MAX_ROWS = 1000

      before_action :set_collection

      def index
        @items = @collection.items.order(updated_at: :desc)
        @items = @items.where(status: params[:status]) if %w[draft published].include?(params[:status])
        @items = @items.limit(MAX_ROWS)
        @leading_fields = @collection.fields.first(4)
      end

      private

      def set_collection
        @collection = ActiveCanvas::Collection.find(params[:collection_id])
      end
    end
  end
end
