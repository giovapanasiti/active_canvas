module ActiveCanvas
  module Admin
    class PagesController < ApplicationController
      before_action :set_page, only: %i[show edit update destroy content update_content editor save_editor versions validate_template sample_data chip_values preview_iframe]

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
        attrs = editor_params
        content_changed = @page.content != attrs[:content]
        Rails.logger.info "[ActiveCanvas::PagesController] save_editor for page ##{@page.id}"
        Rails.logger.info "[ActiveCanvas::PagesController]   content_changed: #{content_changed}"

        result = ActiveCanvas::PageContentUpdate.call(@page, attrs, keep_components: true, validate_template: false)

        if result.success?
          respond_to do |format|
            format.html { redirect_to editor_admin_page_path(@page), notice: "Page saved successfully." }
            format.json do
              render json: {
                success: true,
                message: "Page saved successfully.",
                tailwind: result.tailwind
              }
            end
          end
        else
          errors = result.template_error ? [ result.template_error[:message] ] : result.errors
          respond_to do |format|
            format.html { render :editor, layout: "active_canvas/admin/editor", status: :unprocessable_entity }
            format.json { render json: { success: false, errors: errors }, status: :unprocessable_entity }
          end
        end
      end

      def versions
        @versions = @page.versions.recent.limit(50)
      end

      # Runs the editor's current source through the strict preview renderer
      # and reports the first error with its position. Never returns HTML.
      def validate_template
        result = ActiveCanvas::TemplateValidation.call(
          @page, content: params[:content].to_s, bindings: parse_bindings(params[:bindings]) || {}
        )
        render json: result, status: result[:ok] ? :ok : :unprocessable_entity
      end

      # First rows of one binding, resolved from the editor's unsaved bindings,
      # so an author can see which field names exist before typing {{ }}.
      # Live values for the editor's chips: what each {{ }} shows in its first
      # occurrence and how many items each loop renders.
      def chip_values
        result = ActiveCanvas::TemplateChipValues.call(
          @page, content: params[:content].to_s, bindings: parse_bindings(params[:bindings]) || {}
        )
        render json: result.body, status: result.invalid_bindings? ? :unprocessable_entity : :ok
      end

      def sample_data
        result = ActiveCanvas::BindingSampler.call(
          @page, bindings: parse_bindings(params[:bindings]) || {}, binding: params[:binding].to_s
        )
        return render json: { rows: result.rows } unless result.error

        render json: { error: result.error }, status: result.not_found ? :not_found : :unprocessable_entity
      end

      # Renders a complete HTML page (layout, partials, CSS framework) from the
      # editor's current unsaved state, for the preview modal's iframe. Uses the
      # page's own template_enabled flag so a static page previews as static.
      def preview_iframe
        result = ActiveCanvas::PagePreview.call(
          @page,
          content: params[:content]&.to_s,
          content_css: params[:content_css]&.to_s,
          content_js: params[:content_js]&.to_s,
          bindings: parse_bindings(params[:bindings])
        )

        if result[:error]
          return render json: { html: nil, error: result[:error] }, status: :unprocessable_entity
        end

        render json: { html: result[:html], error: nil }
      end

      def data_sources
        render json: ActiveCanvas::DataSourceCatalog.call
      end

      private

      def set_page
        @page = ActiveCanvas::Page.find(params[:id])
      end

      def page_params
        params.require(:page).permit(
          :title, :slug, :content, :page_type_id, :published, :template_enabled,
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
        params.require(:page).permit(:content, :content_css, :content_js, :content_components, :template_enabled, :bindings)
      end

      # Returns whatever the client sent, parsed. Page#bindings_shape does the
      # checking, so a bad payload becomes a validation error, not a 500.
      def parse_bindings(raw)
        return nil if raw.blank?
        return JSON.parse(raw) if raw.is_a?(String)
        raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
      rescue JSON::ParserError
        raw
      end
    end
  end
end
