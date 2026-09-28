require "test_helper"

class ActiveCanvas::CollectionPageContextTest < ActiveSupport::TestCase
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" } ],
      per_page: 2, title_field: "name", description_field: nil, image_field: nil)
  end

  def publish(name)
    item = @collection.items.new
    item.assign_fields("name" => name)
    item.save!; item.publish!
    item
  end

  test "show returns item and collection" do
    item = publish("Ada")
    context = ActiveCanvas::CollectionPageContext.show(item)
    assert_equal "Ada", context["item"]["name"]
    assert_equal "Team", context["collection"]["name"]
    assert_equal "team", context["collection"]["slug"]
    assert_equal "/canvas/team", context["collection"]["url"]
  end

  test "show honors data: :draft for an unpublished item" do
    item = @collection.items.new
    item.assign_fields("name" => "Draft Ada")
    item.save!

    context = ActiveCanvas::CollectionPageContext.show(item, data: :draft)
    assert_equal "Draft Ada", context["item"]["name"]
  end

  test "index paginates: page, per_page, total_pages, total_items" do
    5.times { |i| publish("Person #{i}") }
    context = ActiveCanvas::CollectionPageContext.index(@collection, page: 1)
    assert_equal 2, context["items"].size
    pagination = context["pagination"]
    assert_equal 1, pagination["page"]
    assert_equal 2, pagination["per_page"]
    assert_equal 3, pagination["total_pages"]
    assert_equal 5, pagination["total_items"]
    assert_nil pagination["prev_url"]
    assert_equal "/canvas/team?page=2", pagination["next_url"]
  end

  test "index prev/next are nil at the edges" do
    5.times { |i| publish("Person #{i}") }

    first = ActiveCanvas::CollectionPageContext.index(@collection, page: 1)
    assert_nil first["pagination"]["prev_url"]
    refute_nil first["pagination"]["next_url"]

    last = ActiveCanvas::CollectionPageContext.index(@collection, page: 3)
    refute_nil last["pagination"]["prev_url"]
    assert_nil last["pagination"]["next_url"]
  end

  test "index middle page prev_url points at page 1 without a query string" do
    5.times { |i| publish("Person #{i}") }
    middle = ActiveCanvas::CollectionPageContext.index(@collection, page: 2)
    assert_equal "/canvas/team", middle["pagination"]["prev_url"]
    assert_equal "/canvas/team?page=3", middle["pagination"]["next_url"]
  end

  test "index on an empty collection renders page 1 with no items" do
    context = ActiveCanvas::CollectionPageContext.index(@collection, page: 1)
    assert_equal [], context["items"]
    assert_equal 1, context["pagination"]["total_pages"]
    assert_equal 0, context["pagination"]["total_items"]
  end

  test "index raises PageOutOfRange below 1 or above total_pages" do
    3.times { |i| publish("Person #{i}") } # per_page 2 => total_pages 2
    assert_raises(ActiveCanvas::CollectionPageContext::PageOutOfRange) do
      ActiveCanvas::CollectionPageContext.index(@collection, page: 0)
    end
    assert_raises(ActiveCanvas::CollectionPageContext::PageOutOfRange) do
      ActiveCanvas::CollectionPageContext.index(@collection, page: 3)
    end
  end

  test "index raises PageOutOfRange for any out-of-range page on an empty collection" do
    assert_raises(ActiveCanvas::CollectionPageContext::PageOutOfRange) do
      ActiveCanvas::CollectionPageContext.index(@collection, page: 2)
    end
  end
end
