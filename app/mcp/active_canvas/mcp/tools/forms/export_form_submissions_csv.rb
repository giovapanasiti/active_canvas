module ActiveCanvas
  module Mcp
    module Tools
      module Forms
        class ExportFormSubmissionsCsv < BaseTool
          tool_name "export_form_submissions_csv"
          description "Export form submissions as CSV, using the same page_id/form_key filters as list_form_submissions. Capped at #{ActiveCanvas::FormSubmissionsCsv::MAX_ROWS} rows. Returns { csv, rows } where rows is the exported row count."
          input_schema(properties: { page_id: { type: "integer" }, form_key: { type: "string" } })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            relation = ActiveCanvas::FormSubmission.includes(:page).order(created_at: :desc)
            relation = relation.where(page_id: args[:page_id]) if args[:page_id].present?
            relation = relation.where(form_key: args[:form_key]) if args[:form_key].present?
            rows = relation.limit(ActiveCanvas::FormSubmissionsCsv::MAX_ROWS).to_a

            { csv: ActiveCanvas::FormSubmissionsCsv.call(rows), rows: rows.size }
          end
        end
      end
    end
  end
end
