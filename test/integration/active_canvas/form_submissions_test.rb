require "test_helper"

class ActiveCanvas::FormSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(
      title: "Contact", slug: "contact-page", published: true, page_type: @page_type,
      content: '<form name="contact"><input type="text" name="full_name" required><input type="email" name="email"></form>'
    )
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @original_cache }

  ORIGIN = { "Origin" => "http://www.example.com" }.freeze

  def token(issued_at: 10.seconds.ago, page: @page, form_key: "contact")
    ActiveCanvas::FormStamper.token_for(page: page, form_key: form_key, issued_at: issued_at)
  end

  def submit(params = {}, headers: ORIGIN, **keyword_params)
    post "/canvas/forms", params: { ac_token: token, full_name: "Ada", email: "ada@example.com", ac_website: "" }.merge(params).merge(keyword_params), headers: headers
  end

  test "valid submission stores filtered data and redirects with feedback params" do
    assert_difference "ActiveCanvas::FormSubmission.count", 1 do
      submit(extra_field: "dropped")
    end
    submission = ActiveCanvas::FormSubmission.last
    assert_equal @page, submission.page
    assert_equal "contact", submission.form_key
    assert_equal({ "full_name" => "Ada", "email" => "ada@example.com" }, submission.data)
    assert_response :redirect
    assert_includes response.headers["Location"], "/canvas/contact-page?ac_submitted=contact"
    assert_includes response.headers["Location"], "#contact"
  end

  test "missing origin and referer is rejected" do
    submit({}, headers: {})
    assert_response :forbidden
  end

  test "cross-origin is rejected" do
    submit({}, headers: { "Origin" => "http://evil.example.net" })
    assert_response :forbidden
  end

  test "referer fallback is accepted when origin is absent" do
    assert_difference "ActiveCanvas::FormSubmission.count", 1 do
      submit({}, headers: { "Referer" => "http://www.example.com/canvas/contact-page" })
    end
  end

  test "missing token is rejected" do
    post "/canvas/forms", params: { full_name: "Ada" }, headers: ORIGIN
    assert_response :unprocessable_entity
  end

  test "tampered token is rejected" do
    submit(ac_token: token + "x")
    assert_response :unprocessable_entity
  end

  test "unpublished page is a 404" do
    @page.update!(published: false)
    submit
    assert_response :not_found
  end

  test "filled honeypot fakes success and stores nothing" do
    assert_no_difference "ActiveCanvas::FormSubmission.count" do
      submit(ac_website: "http://spam.example")
    end
    assert_response :redirect
    assert_includes response.headers["Location"], "ac_submitted=contact"
  end

  test "too-fast submission redirects with error and stores nothing" do
    assert_no_difference "ActiveCanvas::FormSubmission.count" do
      submit(ac_token: token(issued_at: Time.current))
    end
    assert_response :redirect
    assert_includes response.headers["Location"], "ac_form_error=too_fast"
    assert_includes response.headers["Location"], "ac_form=contact"
  end

  test "rate limit returns 429 after the configured burst" do
    ActiveCanvas.config.form_rate_limit_per_minute.times { submit }
    submit
    assert_response :too_many_requests
  end

  test "oversized field value returns 413" do
    submit(email: "x" * 11.kilobytes)
    assert_response :content_too_large
  end

  test "missing required field redirects with error and stores nothing" do
    assert_no_difference "ActiveCanvas::FormSubmission.count" do
      submit(full_name: "")
    end
    assert_includes response.headers["Location"], "ac_form_error=missing_fields"
  end

  test "form removed from content after token issued is rejected" do
    stale = token
    @page.update!(content: "<p>form is gone</p>")
    post "/canvas/forms", params: { ac_token: stale, full_name: "Ada", ac_website: "" }, headers: ORIGIN
    assert_response :unprocessable_entity
  end

  test "notification hook receives the submission and a raising hook does not break the response" do
    received = nil
    ActiveCanvas.config.on_form_submission = ->(submission) { received = submission; raise "boom" }
    submit
    assert_response :redirect
    assert_equal ActiveCanvas::FormSubmission.last, received
  ensure
    ActiveCanvas.config.on_form_submission = nil
  end

  test "instrumentation event fires" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe("form_submission.active_canvas") { |*, payload| events << payload }
    submit
    assert_equal 1, events.size
    assert_kind_of ActiveCanvas::FormSubmission, events.first[:submission]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  test "success feedback is visible on the redirected page" do
    get "/canvas/contact-page", params: { ac_submitted: "contact" }
    assert_response :success
    refute_match(/data-ac-success[^>]*hidden/, response.body)
  end
end
