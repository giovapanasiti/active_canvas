module ActiveCanvas
  module Admin
    class PageTypesController < ApplicationController
      before_action :set_page_type, only: %i[show edit update destroy]

      def index
        @page_types = ActiveCanvas::PageType.order(:name)
      end

      def show
      end

      def new
        @page_type = ActiveCanvas::PageType.new
      end

      def edit
      end

      def create
        @page_type = ActiveCanvas::PageType.new(page_type_params)

        if @page_type.save
          redirect_to admin_page_type_path(@page_type), notice: "Page type was successfully created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @page_type.update(page_type_params)
          redirect_to admin_page_type_path(@page_type), notice: "Page type was successfully updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @page_type.destroy
          redirect_to admin_page_types_path, notice: "Page type was successfully deleted."
        else
          redirect_to admin_page_types_path, alert: @page_type.errors.full_messages.join(", ")
        end
      end

      private

      def set_page_type
        @page_type = ActiveCanvas::PageType.find(params[:id])
      end

      def page_type_params
        params.require(:page_type).permit(:name, :key)
      end
    end
  end
end
