require "test_helper"

class ActiveCanvas::AdminFormSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "P", slug: "p", page_type: @page_type, published: true)
    @other_page = ActiveCanvas::Page.create!(title: "Q", slug: "q", page_type: @page_type, published: true)
    @submission = ActiveCanvas::FormSubmission.create!(
      page: @page, form_key: "contact",
      data: { "email" => "ada@example.com", "message" => "hi" }, ip: "1.2.3.4"
    )
    ActiveCanvas::FormSubmission.create!(page: @other_page, form_key: "newsletter", data: { "email" => "x@y.z" })
  end

  test "index lists submissions" do
    get "/canvas/admin/form_submissions"
    assert_response :success
    assert_includes response.body, "contact"
    assert_includes response.body, "newsletter"
  end

  test "index filters by page and form_key" do
    get "/canvas/admin/form_submissions", params: { page_id: @page.id, form_key: "contact" }
    assert_response :success
    assert_includes response.body, "ada@example.com"
    refute_includes response.body, "newsletter"
  end

  test "show renders the submitted fields" do
    get "/canvas/admin/form_submissions/#{@submission.id}"
    assert_response :success
    assert_includes response.body, "ada@example.com"
    assert_includes response.body, "hi"
  end

  test "destroy removes the submission" do
    assert_difference "ActiveCanvas::FormSubmission.count", -1 do
      delete "/canvas/admin/form_submissions/#{@submission.id}"
    end
    assert_redirected_to "/canvas/admin/form_submissions"
  end

  test "show returns 404 for a missing submission" do
    get "/canvas/admin/form_submissions/999999"
    assert_response :not_found
  end

  test "csv export respects filters and unions data keys" do
    get "/canvas/admin/form_submissions.csv", params: { form_key: "contact" }
    assert_response :success
    assert_equal "text/csv", response.media_type
    header, row = response.body.lines.map(&:strip)
    assert_includes header, "email"
    assert_includes header, "message"
    assert_includes row, "ada@example.com"
    refute_includes response.body, "x@y.z"
  end

  test "csv neutralizes formula injection in submitter data" do
    ActiveCanvas::FormSubmission.create!(page: @page, form_key: "contact", data: { "email" => "=HYPERLINK(\"http://evil\",\"x\")" })
    get "/canvas/admin/form_submissions.csv", params: { form_key: "contact" }
    assert_response :success
    assert_includes response.body, "'=HYPERLINK"
    refute_match(/(?<!')=HYPERLINK/, response.body)
  end
end
