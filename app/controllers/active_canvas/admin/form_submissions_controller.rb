module ActiveCanvas
  module Admin
    class FormSubmissionsController < ApplicationController
      MAX_ROWS = ActiveCanvas::FormSubmissionsCsv::MAX_ROWS

      def index
        @submissions = ActiveCanvas::FormSubmission.includes(:page).order(created_at: :desc)
        @submissions = @submissions.where(page_id: params[:page_id]) if params[:page_id].present?
        @submissions = @submissions.where(form_key: params[:form_key]) if params[:form_key].present?
        @submissions = @submissions.limit(MAX_ROWS)

        respond_to do |format|
          format.html
          format.csv { send_data ActiveCanvas::FormSubmissionsCsv.call(@submissions), filename: "form-submissions-#{Date.current}.csv" }
        end
      end

      def show
        @submission = ActiveCanvas::FormSubmission.find(params[:id])
      end

      def destroy
        ActiveCanvas::FormSubmission.find(params[:id]).destroy
        redirect_to admin_form_submissions_path, notice: "Submission deleted."
      end
    end
  end
end
