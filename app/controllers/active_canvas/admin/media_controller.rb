module ActiveCanvas
  module Admin
    class MediaController < ApplicationController
      def index
        @media = Media.images.recent

        respond_to do |format|
          format.html
          format.json do
            # Support pagination for the asset manager
            page = (params[:page] || 1).to_i
            per_page = (params[:per_page] || 20).to_i

            total_count = @media.count
            paginated_media = @media.offset((page - 1) * per_page).limit(per_page)

            render json: {
              data: paginated_media.map(&:as_json_for_editor),
              meta: {
                current_page: page,
                per_page: per_page,
                total_count: total_count,
                total_pages: (total_count.to_f / per_page).ceil
              }
            }
          end
        end
      end

      def show
        @medium = Media.find(params[:id])
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
          format.html { redirect_to admin_media_url, notice: "Media deleted successfully." }
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
