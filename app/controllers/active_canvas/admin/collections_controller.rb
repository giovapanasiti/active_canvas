module ActiveCanvas
  module Admin
    class CollectionsController < ApplicationController
      def index
        @collections = ActiveCanvas::Collection.order(:name)
      end
    end
  end
end
