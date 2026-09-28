require "test_helper"

class ActiveCanvas::CollectionTemplateTest < ActiveSupport::TestCase
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Bio", "type" => "rich_text" },
                { "label" => "Photo", "type" => "media" } ],
      per_page: 12, title_field: "name", description_field: nil, image_field: nil)
  end

  test "ensure_templates! creates an index and a show template page" do
    @collection.ensure_templates!
    assert_equal 2, @collection.template_pages.count
    assert @collection.template_pages.exists?(collection_role: "index")
    assert @collection.template_pages.exists?(collection_role: "show")
    @collection.template_pages.each do |page|
      assert_nil page.slug
      assert page.template_enabled?
    end
  end

  test "ensure_templates! is idempotent" do
    @collection.ensure_templates!
    ids = @collection.template_pages.order(:collection_role).pluck(:id)
    @collection.ensure_templates!
    assert_equal ids, @collection.template_pages.reload.order(:collection_role).pluck(:id)
    assert_equal 2, @collection.template_pages.count
  end

  test "the starter index template passes TemplateValidation against the implicit context" do
    @collection.ensure_templates!
    index_page = @collection.template_pages.find_by(collection_role: "index")
    context = ActiveCanvas::CollectionPageContext.index(@collection, page: 1)

    result = ActiveCanvas::TemplateValidation.call(index_page, content: index_page.content, bindings: {}, context: context)
    assert result[:ok], result[:error].inspect
  end

  test "the starter show template passes TemplateValidation against the implicit context" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada", "bio" => "<p>Hi</p>")
    item.save!; item.publish!

    @collection.ensure_templates!
    show_page = @collection.template_pages.find_by(collection_role: "show")
    context = ActiveCanvas::CollectionPageContext.show(item.reload)

    result = ActiveCanvas::TemplateValidation.call(show_page, content: show_page.content, bindings: {}, context: context)
    assert result[:ok], result[:error].inspect
  end

  test "the starter index template passes TemplateValidation with at least 2 published items" do
    @collection.ensure_templates!
    item_a = @collection.items.new
    item_a.assign_fields("name" => "Ada", "bio" => "<p>Hi</p>")
    item_a.save!; item_a.publish!
    item_b = @collection.items.new
    item_b.assign_fields("name" => "Bob", "bio" => "<p>Yo</p>")
    item_b.save!; item_b.publish!

    index_page = @collection.template_pages.find_by(collection_role: "index")
    context = ActiveCanvas::CollectionPageContext.index(@collection, page: 1)
    assert_operator context["items"].size, :>=, 2

    result = ActiveCanvas::TemplateValidation.call(index_page, content: index_page.content, bindings: {}, context: context)
    assert result[:ok], result[:error].inspect
  end

  test "the starter show template passes validation with an empty field list" do
    empty_collection = ActiveCanvas::Collection.create!(name: "Empty", slug: "empty", title_field: nil)
    item = empty_collection.items.new
    item.save!; item.publish!

    empty_collection.ensure_templates!
    show_page = empty_collection.template_pages.find_by(collection_role: "show")
    context = ActiveCanvas::CollectionPageContext.show(item.reload)

    result = ActiveCanvas::TemplateValidation.call(show_page, content: show_page.content, bindings: {}, context: context)
    assert result[:ok], result[:error].inspect
  end

  test "destroying the collection removes its templates" do
    @collection.ensure_templates!
    page_ids = @collection.template_pages.pluck(:id)
    @collection.destroy
    assert_empty ActiveCanvas::Page.where(id: page_ids)
  end
end
