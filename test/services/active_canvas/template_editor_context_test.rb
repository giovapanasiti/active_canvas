require "test_helper"

class ActiveCanvas::TemplateEditorContextTest < ActiveSupport::TestCase
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" } ], title_field: "name")
    @collection.update!(has_pages: true)
    @index_page = @collection.template_pages.find_by(collection_role: "index")
    @show_page = @collection.template_pages.find_by(collection_role: "show")
  end

  def publish(name)
    item = @collection.items.new
    item.assign_fields("name" => name)
    item.save!; item.publish!
    item.association(:collection).target = @collection
    item
  end

  test "live returns {} for a regular (non-template) page" do
    page_type = ActiveCanvas::PageType.create!(name: "Test")
    page = ActiveCanvas::Page.create!(title: "p", page_type: page_type, content: "")
    assert_equal({}, ActiveCanvas::TemplateEditorContext.live(page))
  end

  test "live for a show template uses the first published item" do
    publish("Ada")
    publish("Bob")
    context = ActiveCanvas::TemplateEditorContext.live(@show_page)
    assert_equal "Ada", context["item"]["name"]
    assert_equal "Team", context["collection"]["name"]
  end

  test "live for a show template falls back to the first item's draft data when none is published" do
    item = @collection.items.new
    item.assign_fields("name" => "Draft Ada")
    item.save!

    context = ActiveCanvas::TemplateEditorContext.live(@show_page)
    assert_equal "Draft Ada", context["item"]["name"]
  end

  test "live for a show template with no items still resolves item fields (blank) instead of raising" do
    context = ActiveCanvas::TemplateEditorContext.live(@show_page)
    assert_predicate context["item"]["name"].to_s, :blank?
    assert_equal "Team", context["collection"]["name"]
  end

  test "live for an index template always previews page 1" do
    5.times { |i| publish("Person #{i}") }
    context = ActiveCanvas::TemplateEditorContext.live(@index_page)
    assert_equal 1, context["pagination"]["page"]
    assert_kind_of Array, context["items"]
  end

  test "schema for a show template lists item and collection field ids" do
    schema = ActiveCanvas::TemplateEditorContext.schema(@show_page)
    item_ids = schema["item"]["fields"].map { |f| f["id"] }
    assert_includes item_ids, "name"
    assert_includes item_ids, "id"
    assert_includes item_ids, "slug"
    assert_includes item_ids, "url"
    assert_includes item_ids, "seo"
    collection_ids = schema["collection"]["fields"].map { |f| f["id"] }
    assert_equal %w[name slug url], collection_ids
  end

  test "schema for an index template lists items (as entry), collection and pagination field ids" do
    schema = ActiveCanvas::TemplateEditorContext.schema(@index_page)
    assert_equal "entry", schema["items"]["item_name"]
    item_ids = schema["items"]["fields"].map { |f| f["id"] }
    assert_includes item_ids, "name"
    pagination_ids = schema["pagination"]["fields"].map { |f| f["id"] }
    assert_equal %w[page per_page total_pages total_items prev_url next_url], pagination_ids
  end

  test "schema for a regular page is {}" do
    page_type = ActiveCanvas::PageType.create!(name: "Test")
    page = ActiveCanvas::Page.create!(title: "p", page_type: page_type, content: "")
    assert_equal({}, ActiveCanvas::TemplateEditorContext.schema(page))
  end
end
