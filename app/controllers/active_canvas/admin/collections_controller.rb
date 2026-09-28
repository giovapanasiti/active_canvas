module ActiveCanvas
  module Admin
    class CollectionsController < ApplicationController
      before_action :set_collection, only: %i[edit update destroy]

      def index
        @collections = ActiveCanvas::Collection.order(:name)
      end

      def new
        @collection = ActiveCanvas::Collection.new
      end

      def create
        @collection = ActiveCanvas::Collection.new(collection_params)

        if @collection.save
          redirect_to edit_admin_collection_path(@collection), notice: "Collection was successfully created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @collection.update(collection_params)
          redirect_to edit_admin_collection_path(@collection), notice: "Collection was successfully updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @collection.destroy
        redirect_to admin_collections_path, notice: "Collection was successfully deleted."
      end

      private

      def set_collection
        @collection = ActiveCanvas::Collection.find(params[:id])
      end

      def collection_params
        params.require(:collection).permit(:name, :slug, :fields_json, :has_pages, :per_page,
          :show_in_sidebar, :title_field, :description_field, :image_field)
      end
    end
  end
end
