require "test_helper"

class ActiveCanvas::FormStamperTest < ActiveSupport::TestCase
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "P", slug: "p", page_type: @page_type, published: true)
    @html = '<form name="contact"><input type="text" name="email"></form>'
  end

  def stamp(html = @html, feedback: nil, action: nil)
    ActiveCanvas::FormStamper.new(html, page: @page, feedback: feedback, action: action).stamp
  end

  test "sets action and method on every form" do
    doc = Nokogiri::HTML5.fragment(stamp)
    form = doc.at_css("form")
    assert_equal "/canvas/forms", form["action"] # default engine helper carries the dummy's mount prefix
    assert_equal "post", form["method"]
  end

  test "uses the caller-provided action path when given" do
    doc = Nokogiri::HTML5.fragment(stamp(action: "/canvas/forms"))
    assert_equal "/canvas/forms", doc.at_css("form")["action"]
  end

  test "injects a verifiable token bound to page and form" do
    doc = Nokogiri::HTML5.fragment(stamp)
    token = doc.at_css('input[name="ac_token"]')["value"]
    payload = ActiveCanvas::FormStamper.verifier.verify(token)
    assert_equal @page.id, payload["page_id"]
    assert_equal "contact", payload["form_key"]
    assert payload["issued_at"].present?
  end

  test "injects the honeypot field" do
    doc = Nokogiri::HTML5.fragment(stamp)
    honeypot = doc.at_css('input[name="ac_website"]')
    assert honeypot
    assert_includes honeypot["style"], "-9999px"
  end

  test "injects hidden default success and error elements when missing" do
    doc = Nokogiri::HTML5.fragment(stamp)
    assert doc.at_css("form [data-ac-success][hidden]")
    assert doc.at_css("form [data-ac-error][hidden]")
  end

  test "keeps author success element and enforces hidden on it" do
    html = '<form name="contact"><div data-ac-success>Custom thanks</div></form>'
    doc = Nokogiri::HTML5.fragment(stamp(html))
    success = doc.at_css("[data-ac-success]")
    assert_equal "Custom thanks", success.text
    assert success.has_attribute?("hidden")
    assert_equal 1, doc.css("[data-ac-success]").size
  end

  test "re-stamping does not duplicate injected fields" do
    doc = Nokogiri::HTML5.fragment(stamp(stamp))
    assert_equal 1, doc.css('input[name="ac_token"]').size
    assert_equal 1, doc.css('input[name="ac_website"]').size
    assert_equal 1, doc.css("[data-ac-success]").size
  end

  test "unhides success element when feedback matches the form" do
    doc = Nokogiri::HTML5.fragment(stamp(feedback: { submitted: "contact" }))
    refute doc.at_css("[data-ac-success]").has_attribute?("hidden")
  end

  test "leaves success hidden when feedback names another form" do
    doc = Nokogiri::HTML5.fragment(stamp(feedback: { submitted: "other" }))
    assert doc.at_css("[data-ac-success]").has_attribute?("hidden")
  end

  test "unhides error element with a human message" do
    doc = Nokogiri::HTML5.fragment(stamp(feedback: { error: "missing_fields", form_key: "contact" }))
    error = doc.at_css("[data-ac-error]")
    refute error.has_attribute?("hidden")
    assert_match(/required/i, error.text)
  end

  test "passes through content without forms untouched" do
    html = "<p>hello</p>"
    assert_equal html, stamp(html)
  end
end
