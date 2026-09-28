require "test_helper"

class ActiveCanvas::PageTemplateTest < ActiveSupport::TestCase
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" } ],
      per_page: 12, title_field: "name", description_field: nil, image_field: nil)
  end

  test "Page.regular excludes template pages" do
    @collection.ensure_templates!
    regular_page = create_page(content: "hi")

    ids = ActiveCanvas::Page.regular.pluck(:id)
    assert_includes ids, regular_page.id
    @collection.template_pages.each { |p| refute_includes ids, p.id }
  end

  test "a template page's slug is always nil and template_enabled is forced true" do
    @collection.ensure_templates!
    page = @collection.template_pages.first
    page.update!(slug: "whatever", template_enabled: false)
    assert_nil page.reload.slug
    assert page.template_enabled?
  end

  test "a template page cannot be destroyed directly" do
    @collection.ensure_templates!
    page = @collection.template_pages.first
    refute page.destroy
    assert_includes page.errors[:base].join, "removed with their collection"
    assert ActiveCanvas::Page.exists?(page.id)
  end

  test "destroying the collection destroys its template pages" do
    @collection.ensure_templates!
    page_ids = @collection.template_pages.pluck(:id)
    @collection.destroy
    assert_empty ActiveCanvas::Page.where(id: page_ids)
  end

  test "collection_role must be index, show, or nil" do
    page = create_page(content: "hi")
    page.collection_id = @collection.id
    page.collection_role = "bogus"
    refute page.valid?
    assert_includes page.errors[:collection_role].join, "included"
  end

  test "a regular page's slug/template_enabled are untouched" do
    page = create_page(content: "hi")
    page.update!(slug: "custom-slug", template_enabled: true)
    assert_equal "custom-slug", page.reload.slug
    assert page.template_enabled?
  end
end
