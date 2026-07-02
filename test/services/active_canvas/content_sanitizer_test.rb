require "test_helper"

class ActiveCanvas::ContentSanitizerTest < ActiveSupport::TestCase
  setup do
    @original_sanitize = ActiveCanvas.config.sanitize_content
    ActiveCanvas.config.sanitize_content = true
  end

  teardown { ActiveCanvas.config.sanitize_content = @original_sanitize }

  def sanitize(html)
    ActiveCanvas::ContentSanitizer.sanitize_html(html)
  end

  test "href with whitespace-obfuscated javascript scheme is stripped" do
    refute_includes sanitize(%q(<a href="java&#10;script:alert(1)">x</a>)), "script:alert"
  end

  test "href with control-char-prefixed javascript scheme is stripped" do
    refute_includes sanitize(%q(<a href="&#1;javascript:alert(1)">x</a>)), "script:alert"
  end

  test "img src with whitespace-obfuscated javascript scheme is stripped" do
    refute_includes sanitize(%q(<img src="java&#10;script:alert(1)">)), "script:alert"
  end

  test "form action with whitespace-obfuscated javascript scheme is stripped" do
    refute_includes sanitize(%q(<form action="java&#10;script:alert(1)"><input name="a"></form>)), "script:alert"
  end

  test "required attribute survives sanitization" do
    assert_includes sanitize(%q(<input name="a" required>)), "required"
  end

  test "safe href survives sanitization" do
    assert_includes sanitize(%q(<a href="https://example.com">x</a>)), %(href="https://example.com")
  end
end
