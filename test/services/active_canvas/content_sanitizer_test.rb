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


  test "Liquid tags inside attributes survive sanitization untouched" do
    assert_includes sanitize(%q(<a href="{{ url }}">x</a>)), %(href="{{ url }}")
    assert_includes sanitize(%q(<img src="{{ item.photo }}" alt="{{ item.name }}">)), %(src="{{ item.photo }}")
  end

  test "Liquid tags with angle brackets survive sanitization untouched" do
    assert_equal %q({% if a < b and c > d %}y{% endif %}), sanitize(%q({% if a < b and c > d %}y{% endif %}))
  end

  test "Liquid tags never unlock dangerous markup" do
    out = sanitize(%q(<p onclick="{{ x }}">t</p><script>{{ y }}</script><a href="javascript:{{ z }}">l</a>))
    refute_includes out, "onclick"
    refute_includes out, "<script"
    refute_includes out, "javascript:"
  end

  test "text that looks like a placeholder is left alone" do
    assert_includes sanitize("<p>acliquid0z stays</p>"), "acliquid0z stays"
  end
end
