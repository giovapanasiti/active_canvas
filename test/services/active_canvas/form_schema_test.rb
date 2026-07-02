require "test_helper"

class ActiveCanvas::FormSchemaTest < ActiveSupport::TestCase
  HTML = <<~HTML
    <div>
      <form name="contact">
        <input type="text" name="full_name" required>
        <input type="email" name="email" required>
        <textarea name="message"></textarea>
        <select name="topic"><option>a</option></select>
        <input type="hidden" name="ac_token" value="x">
        <input type="text" name="ac_website">
        <input type="file" name="attachment">
        <input type="submit" name="commit" value="Send">
        <input type="text">
        <button type="submit">Send</button>
      </form>
      <form id="newsletter">
        <input type="email" name="email">
      </form>
      <form>
        <input type="text" name="q">
      </form>
    </div>
  HTML

  test "keys derive from name, then id, then position" do
    assert_equal %w[contact newsletter form-3], ActiveCanvas::FormSchema.keys(HTML)
  end

  test "derives allowed fields excluding internals, files, submits and nameless inputs" do
    schema = ActiveCanvas::FormSchema.derive(HTML, "contact")
    assert_equal %w[full_name email message topic], schema.fields
  end

  test "derives required fields" do
    schema = ActiveCanvas::FormSchema.derive(HTML, "contact")
    assert_equal %w[full_name email], schema.required
  end

  test "finds forms by id and by position" do
    assert_equal %w[email], ActiveCanvas::FormSchema.derive(HTML, "newsletter").fields
    assert_equal %w[q], ActiveCanvas::FormSchema.derive(HTML, "form-3").fields
  end

  test "returns nil for a missing form" do
    assert_nil ActiveCanvas::FormSchema.derive(HTML, "nope")
    assert_nil ActiveCanvas::FormSchema.derive("<p>no forms</p>", "contact")
  end
end
