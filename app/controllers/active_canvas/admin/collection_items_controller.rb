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

      def new
        @item = @collection.items.new
      end

      def create
        @item = @collection.items.new(item_params)
        @item.assign_fields(data_params)
        if @item.save
          redirect_to edit_admin_collection_item_path(@collection, @item), notice: "Item saved as draft."
        else
          render :new, status: :unprocessable_entity
        end
      end

      private

      def set_collection
        @collection = ActiveCanvas::Collection.find(params[:collection_id])
      end

      def item_params
        params.fetch(:item, {}).permit(:slug)
      end

      # Field ids are dynamic; assign_fields is a schema allowlist, so reading
      # the raw hash here is safe (unknown keys are dropped by the schema).
      def data_params
        params.dig(:item, :data)&.to_unsafe_h || {}
      end
    end
  end
end
