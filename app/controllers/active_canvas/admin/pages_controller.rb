module ActiveCanvas
  module Admin
    class PagesController < ApplicationController
      before_action :set_page, only: %i[show edit update destroy content update_content editor save_editor versions]

      def index
        @pages = ActiveCanvas::Page.includes(:page_type).order(created_at: :desc)
        @media_count = ActiveCanvas::Media.count
        @media_total_size = ActiveCanvas::Media.sum(:byte_size)
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
              content_js: @page.content_js,
              content_components: @page.content_components
            }
          end
        end
      end

      def save_editor
        content_changed = @page.content != editor_params[:content]
        Rails.logger.info "[ActiveCanvas::PagesController] save_editor for page ##{@page.id}"
        Rails.logger.info "[ActiveCanvas::PagesController]   content_changed: #{content_changed}"

        if @page.update(editor_params)
          tailwind_info = compile_tailwind_if_needed(content_changed)

          respond_to do |format|
            format.html { redirect_to editor_admin_page_path(@page), notice: "Page saved successfully." }
            format.json do
              render json: {
                success: true,
                message: "Page saved successfully.",
                tailwind: tailwind_info
              }
            end
          end
        else
          respond_to do |format|
            format.html { render :editor, layout: "active_canvas/admin/editor", status: :unprocessable_entity }
            format.json { render json: { success: false, errors: @page.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end

      def versions
        @versions = @page.versions.recent.limit(50)
      end

      private

      def compile_tailwind_if_needed(content_changed)
        Rails.logger.info "[ActiveCanvas::PagesController] compile_tailwind_if_needed called"
        Rails.logger.info "[ActiveCanvas::PagesController]   content_changed: #{content_changed}"
        Rails.logger.info "[ActiveCanvas::PagesController]   css_framework: #{Setting.css_framework}"
        Rails.logger.info "[ActiveCanvas::PagesController]   ActiveCanvas::TailwindCompiler.available?: #{ActiveCanvas::TailwindCompiler.available?}"

        unless content_changed
          Rails.logger.info "[ActiveCanvas::PagesController]   Skipping: content unchanged"
          return { compiled: false, reason: "content_unchanged" }
        end

        unless Setting.css_framework == "tailwind"
          Rails.logger.info "[ActiveCanvas::PagesController]   Skipping: not tailwind (#{Setting.css_framework})"
          return { compiled: false, reason: "not_tailwind" }
        end

        unless ActiveCanvas::TailwindCompiler.available?
          Rails.logger.info "[ActiveCanvas::PagesController]   Skipping: gem not available"
          return { compiled: false, reason: "gem_not_available" }
        end

        begin
          Rails.logger.info "[ActiveCanvas::PagesController]   Starting Tailwind compilation..."
          start_time = Time.current
          compiled_css = ActiveCanvas::TailwindCompiler.compile_for_page(@page)
          elapsed_ms = ((Time.current - start_time) * 1000).round

          @page.update_columns(
            compiled_tailwind_css: compiled_css,
            tailwind_compiled_at: Time.current
          )

          Rails.logger.info "[ActiveCanvas::PagesController]   Compilation successful: #{compiled_css.bytesize} bytes in #{elapsed_ms}ms"

          {
            compiled: true,
            success: true,
            css_size: compiled_css.bytesize,
            elapsed_ms: elapsed_ms
          }
        rescue ActiveCanvas::TailwindCompiler::CompilationError => e
          Rails.logger.error "[ActiveCanvas::PagesController] Tailwind compilation failed: #{e.message}"
          {
            compiled: true,
            success: false,
            error: e.message
          }
        end
      end

      def set_page
        @page = ActiveCanvas::Page.find(params[:id])
      end

      def page_params
        params.require(:page).permit(
          :title, :slug, :content, :page_type_id, :published,
          # Header/Footer
          :show_header, :show_footer,
          # SEO fields
          :meta_title, :meta_description, :canonical_url, :meta_robots,
          # Open Graph fields
          :og_title, :og_description, :og_image,
          # Twitter fields
          :twitter_card, :twitter_title, :twitter_description, :twitter_image,
          # Structured data
          :structured_data
        )
      end

      def editor_params
        params.require(:page).permit(:content, :content_css, :content_js, :content_components)
      end
    end
  end
end
