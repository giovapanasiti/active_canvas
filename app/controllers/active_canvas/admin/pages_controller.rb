module ActiveCanvas
  module Admin
    class PagesController < ApplicationController
      include ActiveCanvas::TailwindCompilation

      before_action :set_page, only: %i[show edit update destroy content update_content editor save_editor versions preview_iframe]

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
        if attrs[:bindings].is_a?(String)
          begin
            attrs[:bindings] = JSON.parse(attrs[:bindings])
          rescue JSON::ParserError => e
            return render json: { success: false, error: e.message }, status: :unprocessable_entity
          end
        end

        content_changed = @page.content != attrs[:content]
        Rails.logger.info "[ActiveCanvas::PagesController] save_editor for page ##{@page.id}"
        Rails.logger.info "[ActiveCanvas::PagesController]   content_changed: #{content_changed}"

        if @page.update(attrs)
          tailwind_info = compile_tailwind_if_needed(content_changed) do
            compiled_css = ActiveCanvas::TailwindCompiler.compile_for_page(@page)
            @page.update_columns(compiled_tailwind_css: compiled_css, tailwind_compiled_at: Time.current)
            compiled_css
          end

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

      def render_preview
        page = Page.find(params[:id])
        snapshot = page.dup
        snapshot.content = params[:content].to_s
        snapshot.template_enabled = true
        snapshot.bindings = parse_bindings(params[:bindings])

        html = TemplateRenderer.new(snapshot, mode: :preview).render
        render json: { html: html, error: nil }
      rescue ActiveCanvas::DataSources::TemplateRenderError => e
        render json: { html: nil, error: { message: e.message, line: e.line, column: e.column } },
               status: :unprocessable_entity
      rescue ActiveCanvas::DataSources::Error => e
        render json: { html: nil, error: { message: e.message } }, status: :unprocessable_entity
      end

      # Renders a complete HTML page (with layout, partials, CSS framework, etc.)
      # using the editor's current unsaved state. The response is meant to be
      # loaded directly into an iframe via srcdoc — what visitors would see.
      def preview_iframe
        snapshot = @page.dup
        snapshot.id = @page.id
        snapshot.content = params[:content].to_s if params.key?(:content)
        snapshot.content_css = params[:content_css].to_s if params.key?(:content_css)
        snapshot.content_js = params[:content_js].to_s if params.key?(:content_js)
        snapshot.template_enabled = true
        snapshot.bindings = parse_bindings(params[:bindings])

        # Reuse the public show view + layout so the iframe matches what a
        # visitor would actually see (SEO meta, Tailwind, partials, scripts).
        @page = snapshot
        html = render_to_string(template: "active_canvas/pages/show",
                                layout: "active_canvas/application",
                                formats: [:html])
        render json: { html: html, error: nil }
      rescue ActiveCanvas::DataSources::Error => e
        Rails.logger.warn("[ActiveCanvas] preview_iframe failed: #{e.class}: #{e.message}")
        render json: { html: nil, error: { message: e.message } }, status: :unprocessable_entity
      end

      def data_sources
        sources = ActiveCanvas::DataSources.registered_names.map do |name|
          source = ActiveCanvas::DataSources.lookup(name)
          { name: name, params: source.param_schema }
        end
        render json: sources
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

      def parse_bindings(raw)
        return {} if raw.blank?
        raw.is_a?(String) ? JSON.parse(raw) : raw.to_unsafe_h.to_h
      rescue JSON::ParserError
        {}
      end
    end
  end
end
