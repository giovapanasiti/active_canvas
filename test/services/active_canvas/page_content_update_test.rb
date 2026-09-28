require "test_helper"

class ActiveCanvas::PageContentUpdateTest < ActiveSupport::TestCase
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "<p>old</p>", content_components: "orig-components")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "a static page's content change clears content_components by default" do
    result = ActiveCanvas::PageContentUpdate.call(@page, { content: "<p>new</p>" })

    assert result.success?
    assert_nil @page.reload.content_components
  end

  test "keep_components: true preserves content_components on a content change" do
    result = ActiveCanvas::PageContentUpdate.call(@page, { content: "<p>new</p>" }, keep_components: true)

    assert result.success?
    assert_equal "orig-components", @page.reload.content_components
  end

  test "a string bindings value is parsed" do
    result = ActiveCanvas::PageContentUpdate.call(
      @page,
      { content: "Hi {{ name }}", template_enabled: true, bindings: { name: { source: "_literal", value: "Liz" } }.to_json }
    )

    assert result.success?, result.errors.inspect
    assert_equal "Liz", @page.reload.bindings.dig("name", "value")
  end

  test "invalid JSON bindings gives an error and saves nothing" do
    result = ActiveCanvas::PageContentUpdate.call(@page, { content: "x", bindings: "{not json" })

    refute result.success?
    assert_equal 1, result.errors.size
    assert_match(/Bindings:/, result.errors.first)
    assert_equal "<p>old</p>", @page.reload.content
  end

  test "template_enabled with invalid Liquid returns a template_error with a line, and saves nothing" do
    assert_no_difference -> { @page.versions.count } do
      result = ActiveCanvas::PageContentUpdate.call(@page, { content: "{% if %}", template_enabled: true })

      refute result.success?
      assert result.template_error
      assert_kind_of String, result.template_error[:message]
      assert result.template_error[:line]
    end
    assert_equal "<p>old</p>", @page.reload.content
  end

  test "valid content creates exactly one PageVersion with changed_by set to Current.editor" do
    ActiveCanvas::Current.editor = "agent-1"

    assert_difference -> { @page.versions.count }, 1 do
      result = ActiveCanvas::PageContentUpdate.call(@page, { content: "<p>brand new</p>" })
      assert result.success?
    end

    assert_equal "agent-1", @page.versions.last.changed_by
  ensure
    ActiveCanvas::Current.editor = nil
  end

  test "invalid bindings shape fails validation without saving" do
    result = ActiveCanvas::PageContentUpdate.call(@page, { content: "x", bindings: { "x" => 5 } })

    refute result.success?
    assert_match(/bindings/i, result.errors.join)
  end

  test "on a collection template page, template validation applies the implicit item context" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    template = collection.template_pages.find_by!(collection_role: "show")

    result = ActiveCanvas::PageContentUpdate.call(template, { content: "<h1>{{ item.name }}</h1>" })

    assert result.success?, result.errors.inspect
    assert_equal "<h1>{{ item.name }}</h1>", template.reload.content
  end

  test "validate_template: false saves invalid Liquid on a template_enabled page instead of rejecting it" do
    result = ActiveCanvas::PageContentUpdate.call(
      @page, { content: "{% if %}", template_enabled: true }, validate_template: false
    )

    assert result.success?, result.errors.inspect
    assert_nil result.template_error
    assert_equal "{% if %}", @page.reload.content
  end
end
