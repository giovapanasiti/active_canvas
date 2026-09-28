require "test_helper"

class ActiveCanvas::Mcp::FormsToolsTest < ActionDispatch::IntegrationTest
  setup do
    @rw = mcp_token(%w[read write])
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "Contact", page_type: @page_type)
    @other_page = ActiveCanvas::Page.create!(title: "Other", page_type: @page_type)

    @sub1 = ActiveCanvas::FormSubmission.create!(page: @page, form_key: "contact", data: { "email" => "a@example.com" }, ip: "1.1.1.1")
    @sub2 = ActiveCanvas::FormSubmission.create!(page: @other_page, form_key: "newsletter", data: { "email" => "b@example.com" }, ip: "2.2.2.2")
  end

  test "list_form_submissions filters by page_id" do
    listed, err = mcp_call(@rw, "list_form_submissions", { page_id: @page.id })
    assert_nil err
    ids = listed["items"].map { |i| i["id"] }
    assert_includes ids, @sub1.id
    refute_includes ids, @sub2.id
  end

  test "list_form_submissions filters by form_key" do
    listed, = mcp_call(@rw, "list_form_submissions", { form_key: "newsletter" })
    ids = listed["items"].map { |i| i["id"] }
    assert_equal [ @sub2.id ], ids
  end

  test "list_form_submissions returns the paginated envelope" do
    listed, = mcp_call(@rw, "list_form_submissions")
    assert_equal ActiveCanvas::FormSubmission.count, listed["total"]
    assert_equal 50, listed["limit"]
    assert_equal 0, listed["offset"]
  end

  test "get_form_submission returns full data" do
    fetched, err = mcp_call(@rw, "get_form_submission", { id: @sub1.id })
    assert_nil err
    assert_equal @sub1.id, fetched["id"]
    assert_equal @page.id, fetched["page_id"]
    assert_equal "contact", fetched["form_key"]
    assert_equal({ "email" => "a@example.com" }, fetched["data"])
    assert_equal "1.1.1.1", fetched["ip"]
  end

  test "get_form_submission not found is a tool error" do
    _, err = mcp_call(@rw, "get_form_submission", { id: 999_999 })
    assert_match(/not found/, err)
  end

  test "delete_form_submission works" do
    deleted, err = mcp_call(@rw, "delete_form_submission", { id: @sub1.id })
    assert_nil err
    assert_equal true, deleted["deleted"]
    assert_nil ActiveCanvas::FormSubmission.find_by(id: @sub1.id)
  end

  test "delete_form_submission requires write scope" do
    ro = mcp_token(%w[read])
    refute_includes mcp_tool_names(ro), "delete_form_submission"
  end

  test "export_form_submissions_csv contains a header row and respects filters" do
    result, err = mcp_call(@rw, "export_form_submissions_csv", { page_id: @page.id })
    assert_nil err
    assert result["csv"].start_with?("id,page,form,created_at,ip")
    assert_equal 1, result["rows"]
    assert_includes result["csv"], "contact"
    refute_includes result["csv"], "newsletter"
  end
end
