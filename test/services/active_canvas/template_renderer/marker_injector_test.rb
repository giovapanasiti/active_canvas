require "test_helper"

class ActiveCanvas::TemplateRenderer::MarkerInjectorTest < ActiveSupport::TestCase
  def inject(src)
    ActiveCanvas::TemplateRenderer::MarkerInjector.new(src).inject
  end

  test "wraps simple {{ var }} with marker span" do
    out = inject("Hello {{ name }}!")
    assert_match(/<span data-ac-var="name" data-ac-source="\{% raw %\}\{\{ name \}\}\{% endraw %\}" class="ac-chip">\{\{ name \}\}<\/span>/, out)
  end

  test "data-ac-source survives Liquid render and preserves the original tag" do
    injected = inject("Hello {{ name }}!")
    rendered = Liquid::Template.parse(injected, error_mode: :strict).render!("name" => "World")
    # Attribute keeps the original Liquid tag literally (no substitution inside).
    assert_match(/data-ac-source="\{\{ name \}\}"/, rendered)
    # Chip body is rendered.
    assert_match(/<span[^>]*class="ac-chip">World<\/span>/, rendered)
  end

  test "for-block with HTML in body produces well-formed nested chips after Liquid render" do
    injected = inject("<ul>{% for item in items %}<li>{{ item }}</li>{% endfor %}</ul>")
    rendered = Liquid::Template.parse(injected, error_mode: :strict).render!("items" => %w[a b c])
    # Outer attribute survives intact (HTML-escaped original source).
    assert_match(/data-ac-source="\{% for item in items %\}&lt;li&gt;\{\{ item \}\}&lt;\/li&gt;\{% endfor %\}"/, rendered)
    # Inner chips render each item.
    %w[a b c].each { |v| assert_match(/<span[^>]*class="ac-chip">#{v}<\/span>/, rendered) }
    # No broken attributes: count of < and > inside attributes should not desync.
    refute_match(/data-ac-source="[^"]*<span/, rendered, "data-ac-source should not contain a raw <span> (attribute boundary broken)")
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
