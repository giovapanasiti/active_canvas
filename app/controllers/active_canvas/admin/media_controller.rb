module ActiveCanvas
  module Admin
    class MediaController < ApplicationController
      def index
        @media = Media.images.recent

        respond_to do |format|
          format.html
          format.json do
            render json: {
              data: @media.map(&:as_json_for_editor)
            }
          end
        end
      end

      def create
        @media = Media.new(media_params)

        if @media.save
          render json: @media.as_json_for_editor, status: :created
        else
          render json: { errors: @media.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @media = Media.find(params[:id])
        @media.destroy

        respond_to do |format|
          format.html { redirect_to admin_media_path, notice: "Media deleted successfully." }
          format.json { head :no_content }
        end
      end

      private

      def media_params
        params.require(:media).permit(:file, :filename)
      end
    end
  end
end
