require "csv"

module ActiveCanvas
  module Admin
    class FormSubmissionsController < ApplicationController
      MAX_ROWS = 1000

      def index
        @submissions = ActiveCanvas::FormSubmission.includes(:page).order(created_at: :desc)
        @submissions = @submissions.where(page_id: params[:page_id]) if params[:page_id].present?
        @submissions = @submissions.where(form_key: params[:form_key]) if params[:form_key].present?
        @submissions = @submissions.limit(MAX_ROWS)

        respond_to do |format|
          format.html
          format.csv { send_data csv_for(@submissions), filename: "form-submissions-#{Date.current}.csv" }
        end
      end

      def show
        @submission = ActiveCanvas::FormSubmission.find(params[:id])
      end

      def destroy
        ActiveCanvas::FormSubmission.find(params[:id]).destroy
        redirect_to admin_form_submissions_path, notice: "Submission deleted."
      end

      private

      def csv_for(submissions)
        data_keys = submissions.flat_map { |submission| submission.data.keys }.uniq
        CSV.generate do |csv|
          csv << [ "id", "page", "form", "created_at", "ip", *data_keys ]
          submissions.each do |submission|
            csv << [ submission.id, submission.page.title, submission.form_key,
                     submission.created_at.iso8601, submission.ip,
                     *data_keys.map { |key| submission.data[key] } ]
          end
        end
      end
    end
  end
end
