module ActiveCanvas
  module Admin
    class PartialsController < ApplicationController
      include ActiveCanvas::TailwindCompilation

      before_action :ensure_partials_exist, only: [:index]
      before_action :set_partial, only: %i[edit update editor save_editor]

      def index
        @partials = ActiveCanvas::Partial.order(:partial_type)
      end

      def edit
      end

      def update
        if @partial.update(partial_params)
          redirect_to admin_partials_path, notice: "#{@partial.name} was successfully updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def editor
        respond_to do |format|
          format.html { render layout: "active_canvas/admin/editor" }
          format.json do
            render json: {
              content: @partial.content,
              content_css: @partial.content_css,
              content_js: @partial.content_js,
              content_components: @partial.content_components
            }
          end
        end
      end

      def save_editor
        content_changed = @partial.content != editor_params[:content]

        if @partial.update(editor_params)
          tailwind_info = compile_tailwind_if_needed(content_changed) do
            compiled_css = ActiveCanvas::TailwindCompiler.compile(
              @partial.content.to_s,
              identifier: "partial ##{@partial.id} (#{@partial.name})"
            )
            @partial.update_columns(compiled_css: compiled_css)
            compiled_css
          end

          respond_to do |format|
            format.html { redirect_to editor_admin_partial_path(@partial), notice: "#{@partial.name} saved successfully." }
            format.json do
              render json: {
                success: true,
                message: "#{@partial.name} saved successfully.",
                tailwind: tailwind_info
              }
            end
          end
        else
          respond_to do |format|
            format.html { render :editor, layout: "active_canvas/admin/editor", status: :unprocessable_entity }
            format.json { render json: { success: false, errors: @partial.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end

      private

      def ensure_partials_exist
        ActiveCanvas::Partial.ensure_defaults!
      end

      def set_partial
        @partial = ActiveCanvas::Partial.find(params[:id])
      end

      def partial_params
        params.require(:partial).permit(:name, :active)
      end

      def editor_params
        params.require(:partial).permit(:content, :content_css, :content_js, :content_components)
      end
    end
  end
end
