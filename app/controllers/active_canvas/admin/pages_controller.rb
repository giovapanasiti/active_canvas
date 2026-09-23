module ActiveCanvas
  module Admin
    class PagesController < ApplicationController
      include ActiveCanvas::TailwindCompilation

      before_action :set_page, only: %i[show edit update destroy content update_content editor save_editor versions validate_template sample_data preview_iframe]

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

      # Runs the editor's current source through the strict preview renderer
      # and reports the first error with its position. Never returns HTML.
      def validate_template
        preview = @page.preview_with(content: params[:content].to_s, bindings: parse_bindings(params[:bindings]) || {}, template_enabled: true)

        if (message = invalid_bindings_message(preview))
          return render json: { ok: false, error: { message: message } }, status: :unprocessable_entity
        end

        TemplateRenderer.new(preview, mode: :preview).render
        render json: { ok: true, error: nil }
      rescue ActiveCanvas::DataSources::TemplateRenderError => e
        render json: { ok: false, error: { message: e.message, line: e.line, column: e.column } },
               status: :unprocessable_entity
      end

      # First rows of one binding, resolved from the editor's unsaved bindings,
      # so an author can see which field names exist before typing {{ }}.
      def sample_data
        preview = @page.preview_with(bindings: parse_bindings(params[:bindings]) || {})

        if (message = invalid_bindings_message(preview))
          return render json: { error: message }, status: :unprocessable_entity
        end

        name = params[:binding].to_s
        return render json: { error: "No binding named #{name.inspect}" }, status: :not_found unless preview.bindings.key?(name)

        render json: { rows: TemplateRenderer::BindingResolver.new(preview.bindings).sample(name) }
      rescue StandardError => e
        Rails.logger.warn("[ActiveCanvas] sample_data for page #{@page.id} failed: #{e.class}: #{e.message}")
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # Renders a complete HTML page (layout, partials, CSS framework) from the
      # editor's current unsaved state, for the preview modal's iframe. Uses the
      # page's own template_enabled flag so a static page previews as static.
      def preview_iframe
        preview = @page.preview_with(
          content: params[:content]&.to_s,
          content_css: params[:content_css]&.to_s,
          content_js: params[:content_js]&.to_s,
          bindings: parse_bindings(params[:bindings])
        )

        if (message = invalid_bindings_message(preview))
          return render json: { html: nil, error: { message: message } }, status: :unprocessable_entity
        end

        @page = preview
        html = render_to_string(template: "active_canvas/pages/show",
                                layout: "active_canvas/application",
                                formats: [ :html ])
        render json: { html: html, error: nil }
      end

      def data_sources
        literal = {
          name: "_literal", kind: "literal", label: "Literal", item_name: "item", list: false,
          params: { value: { type: :string, default: nil, range: nil, allowed: nil } }
        }

        registered = ActiveCanvas::DataSources.registered_names.map do |name|
          source = ActiveCanvas::DataSources.lookup(name)
          {
            name: name, kind: "source", label: name.to_s.humanize,
            item_name: ActiveCanvas::DataSources.item_name(name), list: source.list?,
            params: source.param_schema
          }
        end

        collections = ActiveCanvas::Collection.order(:name).map do |collection|
          {
            name: collection.slug, kind: "collection", label: collection.name,
            item_name: collection.item_name, list: true,
            fields: collection.fields.map { |f| f.slice("id", "label", "type", "options") },
            params: collection.param_schema
          }
        end

        render json: [ literal ] + registered + collections
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

      # A dup'd page fails the slug uniqueness check against its own row, so
      # only the bindings errors are meaningful here.
      def invalid_bindings_message(page)
        page.validate
        page.errors.full_messages_for(:bindings).to_sentence.presence
      end
    end
  end
end
