require "test_helper"

class ActiveCanvas::PageDynamicTest < ActiveSupport::TestCase
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "rendered_content uses TemplateRenderer for dynamic pages" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hi {{ name }}", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "Jane" } }
    )
    assert_includes page.rendered_content, "Hi Jane"
    assert page.rendered_content.html_safe?
  end

  test "rendered_content returns raw content for static pages" do
    page = ActiveCanvas::Page.create!(
      title: "Static", page_type: @page_type,
      content: "<h1>Static</h1>", template_enabled: false
    )
    assert_equal "<h1>Static</h1>", page.rendered_content.to_s
  end

  test "version is created when bindings change" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hi", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "Jane" } }
    )
    assert_difference -> { page.versions.count } do
      page.update!(bindings: { "name" => { "source" => "_literal", "value" => "John" } })
    end
    v = page.versions.last
    assert_equal({ "name" => { "source" => "_literal", "value" => "Jane" } }, v.bindings_before)
    assert_equal({ "name" => { "source" => "_literal", "value" => "John" } }, v.bindings_after)
  end

  test "bindings must be a hash of hashes that each name a source" do
    page = ActiveCanvas::Page.new(title: "Dyn", page_type: @page_type, content: "")
    [ [ 1 ], "str", { "x" => 5 }, { "x" => nil }, { "x" => "notahash" }, { "x" => { "value" => 1 } }, { "x" => { "source" => "" } } ].each do |bad|
      page.bindings = bad
      assert_not page.valid?, "expected #{bad.inspect} to be invalid"
      assert page.errors[:bindings].any?, "expected a bindings error for #{bad.inspect}"
    end
  end

  test "well-formed bindings are valid" do
    page = ActiveCanvas::Page.new(title: "Dyn", page_type: @page_type, content: "",
      bindings: { "x" => { "source" => "_literal", "value" => 1 }, "y" => { "source" => "posts", "params" => {} } })
    assert page.valid?
  end

  test "empty bindings are valid" do
    page = ActiveCanvas::Page.new(title: "Dyn", page_type: @page_type, content: "", bindings: {})
    assert page.valid?
  end

  test "dynamic page content is stored byte-for-byte, even Liquid inside a table" do
    source = "<table><tbody>{% for r in rows %}<tr><td>{{ r }}</td></tr>{% endfor %}</tbody></table>{% if a <b %}x{% endif %}"
    page = ActiveCanvas::Page.create!(title: "Dyn", page_type: @page_type, content: source, template_enabled: true)
    assert_equal source, page.reload.content
  end

  test "static page content is still sanitized on save" do
    page = ActiveCanvas::Page.create!(title: "S", page_type: @page_type,
      content: "<p>ok</p><script>alert(1)</script>", template_enabled: false)
    refute_includes page.reload.content, "<script>"
  end

  test "turning dynamic rendering off sanitizes the stored content" do
    page = ActiveCanvas::Page.create!(title: "Dyn", page_type: @page_type,
      content: "<p>ok</p><script>alert(1)</script>", template_enabled: true)
    assert_includes page.reload.content, "<script>"
    page.update!(template_enabled: false)
    refute_includes page.reload.content, "<script>"
  end

  test "dynamic page output is sanitized after render" do
    page = ActiveCanvas::Page.create!(title: "Dyn", page_type: @page_type,
      content: "<p>ok</p><script>alert(1)</script>", template_enabled: true)
    refute_includes page.rendered_content, "<script>"
  end

  test "preview_with returns an unsaved copy with the same id and the overrides" do
    page = ActiveCanvas::Page.create!(title: "Dyn", page_type: @page_type, content: "old",
      template_enabled: false, bindings: {})
    preview = page.preview_with(content: "new {{ x }}", bindings: { "x" => { "source" => "_literal", "value" => 1 } }, template_enabled: true)
    assert preview.new_record?
    assert_equal page.id, preview.id
    assert_equal "new {{ x }}", preview.content
    assert preview.template_enabled?
    assert_equal "old", page.reload.content
    assert_not page.template_enabled?
  end

  test "preview_with keeps fields that are not overridden" do
    page = ActiveCanvas::Page.create!(title: "Dyn", page_type: @page_type, content: "keep", content_css: "p{}", template_enabled: true)
    preview = page.preview_with(bindings: {})
    assert_equal "keep", preview.content
    assert_equal "p{}", preview.content_css
    assert preview.template_enabled?
  end
end
