require "test_helper"

class ActiveCanvas::TemplateRenderer::MarkerInjectorTest < ActiveSupport::TestCase
  def inject(src)
    ActiveCanvas::TemplateRenderer::MarkerInjector.new(src).inject
  end

  test "wraps simple {{ var }} with marker span" do
    out = inject("Hello {{ name }}!")
    assert_match(/<span data-ac-var="name" data-ac-source="\{\{ name \}\}" class="ac-chip">\{\{ name \}\}<\/span>/, out)
  end

  test "wraps multiple variables independently" do
    out = inject("{{ a }} {{ b }}")
    assert_equal 2, out.scan(/data-ac-var=/).size
  end

  test "wraps {% for %} block whole" do
    out = inject("{% for x in items %}{{ x }}{% endfor %}")
    assert_match(/<span data-ac-block="for x in items" .*class="ac-block">.*<\/span>/m, out)
  end

  test "wraps {% if %} block whole" do
    out = inject("{% if a %}A{% endif %}")
    assert_match(/<span data-ac-block="if a" .*class="ac-block">.*<\/span>/m, out)
  end

  test "leaves plain HTML untouched" do
    assert_equal "<p>plain</p>", inject("<p>plain</p>")
  end

  test "does not wrap tags inside HTML attributes (skips href, src, etc.)" do
    out = inject('<a href="{{ url }}">click</a>')
    # The attribute should remain valid HTML; markers must NOT inject inside an attribute.
    assert_match(/<a href="\{\{ url \}\}">click<\/a>/, out)
  end
end
