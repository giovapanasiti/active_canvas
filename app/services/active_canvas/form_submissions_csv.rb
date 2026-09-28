require "csv"

module ActiveCanvas
  # Renders a FormSubmission relation as CSV, with dynamic headers unioned
  # from every submission's data keys. Used by Admin::FormSubmissionsController
  # (index.csv) and the `export_form_submissions_csv` MCP tool.
  class FormSubmissionsCsv
    MAX_ROWS = 1000

    def self.call(relation)
      new(relation).call
    end

    def initialize(relation)
      @relation = relation
    end

    def call
      data_keys = @relation.flat_map { |submission| submission.data.keys }.uniq

      CSV.generate do |csv|
        csv << [ "id", "page", "form", "created_at", "ip", *data_keys ]
        @relation.each do |submission|
          csv << [
            submission.id, csv_cell(submission.page.title), csv_cell(submission.form_key),
            submission.created_at.iso8601, submission.ip,
            *data_keys.map { |key| csv_cell(submission.data[key]) }
          ]
        end
      end
    end

    private

    # Neutralize CSV formula injection: submitter-controlled values that begin
    # with a formula trigger execute when the export is opened in a spreadsheet.
    def csv_cell(value)
      string = value.to_s
      string.match?(/\A[=+\-@\t\r]/) ? "'#{string}" : string
    end
  end
end
