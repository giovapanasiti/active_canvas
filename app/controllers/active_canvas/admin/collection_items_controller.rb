module ActiveCanvas
  module Admin
    class CollectionItemsController < ApplicationController
      MAX_ROWS = 1000

      before_action :set_collection
      before_action :set_item, only: %i[edit update destroy publish unpublish history]

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

      def edit
      end

      def update
        @item.assign_attributes(item_params)
        @item.assign_fields(data_params)
        if @item.save
          redirect_to edit_admin_collection_item_path(@collection, @item), notice: "Item updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @item.destroy
        redirect_to admin_collection_items_path(@collection), notice: "Item deleted."
      end

      def publish
        ActiveCanvas::CollectionItem.current_editor = collection_item_editor_label
        if @item.publish
          redirect_to edit_admin_collection_item_path(@collection, @item), notice: "Item published."
        else
          redirect_to edit_admin_collection_item_path(@collection, @item), alert: @item.errors.full_messages.to_sentence
        end
      ensure
        ActiveCanvas::CollectionItem.current_editor = nil
      end

      def unpublish
        @item.unpublish!
        redirect_to edit_admin_collection_item_path(@collection, @item), notice: "Item moved back to draft."
      end

      def history
        @versions = @item.versions.order(version_number: :desc)
      end

      private

      def set_collection
        @collection = ActiveCanvas::Collection.find(params[:collection_id])
      end

      def set_item
        @item = @collection.items.find(params[:id])
      end

      def item_params
        params.fetch(:item, {}).permit(:slug)
      end

      # Field ids are dynamic; assign_fields is a schema allowlist, so reading
      # the raw hash here is safe (unknown keys are dropped by the schema).
      def data_params
        data = params.dig(:item, :data)
        data.respond_to?(:to_unsafe_h) ? data.to_unsafe_h : {}
      end

      # A display label for the audit trail. Uses the host app's current user
      # (via the CurrentUser concern) when one is wired; nil otherwise.
      def collection_item_editor_label
        active_canvas_current_user&.to_s
      end
    end
  end
end
