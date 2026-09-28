require "test_helper"

class ActiveCanvas::FormSubmissionsCsvTest < ActiveSupport::TestCase
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "P", page_type: @page_type)
  end

  test "headers are the union of every submission's data keys" do
    ActiveCanvas::FormSubmission.create!(page: @page, form_key: "contact", data: { "email" => "a@example.com" })
    ActiveCanvas::FormSubmission.create!(page: @page, form_key: "contact", data: { "email" => "b@example.com", "message" => "hi" })

    csv = ActiveCanvas::FormSubmissionsCsv.call(ActiveCanvas::FormSubmission.order(:id))
    header = csv.lines.first

    assert_includes header, "email"
    assert_includes header, "message"
  end

  test "a value starting with = is neutralized against formula injection" do
    ActiveCanvas::FormSubmission.create!(page: @page, form_key: "contact", data: { "email" => "=HYPERLINK(\"http://evil\")" })

    csv = ActiveCanvas::FormSubmissionsCsv.call(ActiveCanvas::FormSubmission.order(:id))

    assert_includes csv, "'=HYPERLINK"
    refute_match(/(?<!')=HYPERLINK/, csv)
  end
end
