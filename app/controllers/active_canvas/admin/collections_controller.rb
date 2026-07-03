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
        return render(:new, status: :unprocessable_entity) unless assign_fields_json(@collection)

        if @collection.save
          redirect_to edit_admin_collection_path(@collection), notice: "Collection was successfully created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        @collection.assign_attributes(collection_params)
        return render(:edit, status: :unprocessable_entity) unless assign_fields_json(@collection)

        if @collection.save
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
        params.require(:collection).permit(:name, :slug)
      end

      # Parse the field-builder's JSON payload into the fields array. Returns
      # false (and flags an error) on malformed JSON so the caller can re-render.
      def assign_fields_json(collection)
        raw = params.dig(:collection, :fields)
        parsed = raw.blank? ? [] : JSON.parse(raw)
        unless parsed.is_a?(Array) && parsed.all?(Hash)
          collection.errors.add(:fields, "could not be read")
          return false
        end
        collection.fields = parsed
        true
      rescue JSON::ParserError
        collection.errors.add(:fields, "could not be read")
        false
      end
    end
  end
end
