module ActiveCanvas
  module Admin
    class PagesController < ApplicationController
      before_action :set_page, only: %i[show edit update destroy content update_content editor save_editor]

      def index
        @pages = ActiveCanvas::Page.includes(:page_type).order(created_at: :desc)
      end

      def show
      end

      def new
        @page = ActiveCanvas::Page.new(page_type: ActiveCanvas::PageType.default)
      end

      def edit
      end

      def create
        @page = ActiveCanvas::Page.new(page_params)

        if @page.save
          redirect_to admin_page_path(@page), notice: "Page was successfully created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @page.update(page_params)
          redirect_to admin_page_path(@page), notice: "Page was successfully updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @page.destroy
        redirect_to admin_pages_path, notice: "Page was successfully deleted."
      end

      def content
      end

      def update_content
        if @page.update(params.require(:page).permit(:content))
          redirect_to content_admin_page_path(@page), notice: "Content saved."
        else
          render :content, status: :unprocessable_entity
        end
      end

      def editor
        respond_to do |format|
          format.html { render layout: "active_canvas/admin/editor" }
          format.json do
            render json: {
              content: @page.content,
              content_css: @page.content_css,
              content_components: @page.content_components
            }
          end
        end
      end

      def save_editor
        if @page.update(editor_params)
          respond_to do |format|
            format.html { redirect_to editor_admin_page_path(@page), notice: "Page saved successfully." }
            format.json { render json: { success: true, message: "Page saved successfully." } }
          end
        else
          respond_to do |format|
            format.html { render :editor, layout: "active_canvas/admin/editor", status: :unprocessable_entity }
            format.json { render json: { success: false, errors: @page.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end

      private

      def set_page
        @page = ActiveCanvas::Page.find(params[:id])
      end

      def page_params
        params.require(:page).permit(:title, :slug, :content, :page_type_id, :published)
      end

      def editor_params
        params.require(:page).permit(:content, :content_css, :content_components)
      end
    end
  end
end
