module ActiveCanvas
  module Mcp
    module Tools
      module Forms
        class ListFormSubmissions < BaseTool
          tool_name "list_form_submissions"
          description "List form submissions, newest first. Filter by page_id and/or form_key."
          input_schema(properties: {
            page_id: { type: "integer" },
            form_key: { type: "string" },
            limit: { type: "integer" },
            offset: { type: "integer" }
          })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            relation = ActiveCanvas::FormSubmission.includes(:page).order(created_at: :desc)
            relation = relation.where(page_id: args[:page_id]) if args[:page_id].present?
            relation = relation.where(form_key: args[:form_key]) if args[:form_key].present?

            page = paginate(relation, args)
            page.merge(items: page[:items].map { |s| Serializers.form_submission(s) })
          end
        end
      end
    end
  end
end
