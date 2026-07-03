module ActiveCanvas
  module Admin
    class CollectionsController < ApplicationController
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

      private

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
