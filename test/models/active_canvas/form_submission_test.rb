require "test_helper"

class ActiveCanvas::FormSubmissionTest < ActiveSupport::TestCase
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "P", slug: "p", page_type: @page_type)
  end

  test "valid with page, form_key and data" do
    submission = ActiveCanvas::FormSubmission.new(page: @page, form_key: "contact", data: { "email" => "a@b.c" })
    assert submission.valid?
  end

  test "requires form_key" do
    submission = ActiveCanvas::FormSubmission.new(page: @page, data: {})
    assert_not submission.valid?
  end

  test "requires page" do
    submission = ActiveCanvas::FormSubmission.new(form_key: "contact", data: {})
    assert_not submission.valid?
  end

  test "data defaults to empty hash" do
    submission = ActiveCanvas::FormSubmission.create!(page: @page, form_key: "contact")
    assert_equal({}, submission.reload.data)
  end

  test "destroying a page destroys its submissions" do
    ActiveCanvas::FormSubmission.create!(page: @page, form_key: "contact")
    @page.destroy
    assert_equal 0, ActiveCanvas::FormSubmission.count
  end
end
