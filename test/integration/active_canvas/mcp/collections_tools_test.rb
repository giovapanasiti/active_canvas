require "test_helper"

class ActiveCanvas::Mcp::CollectionsToolsTest < ActionDispatch::IntegrationTest
  setup { @rw = mcp_token(%w[read write]) }

  def fields
    [
      { "label" => "Name", "type" => "text", "required" => true },
      { "label" => "Bio", "type" => "textarea" }
    ]
  end

  test "create, list, get (by id and slug), update, delete" do
    created, err = mcp_call(@rw, "create_collection", { name: "Team", fields: fields })
    assert_nil err
    assert_equal "team", created["slug"]
    assert_equal 2, created["fields"].length
    assert_equal 0, created["items_count"]

    listed, = mcp_call(@rw, "list_collections")
    assert_includes listed["items"].map { |i| i["name"] }, "Team"

    by_id, = mcp_call(@rw, "get_collection", { id: created["id"] })
    assert_equal "Team", by_id["name"]

    by_slug, = mcp_call(@rw, "get_collection", { slug: "team" })
    assert_equal created["id"], by_slug["id"]

    updated, = mcp_call(@rw, "update_collection", { id: created["id"], name: "Team 2" })
    assert_equal "Team 2", updated["name"]
    assert_equal 2, updated["fields"].length

    deleted, = mcp_call(@rw, "delete_collection", { id: created["id"] })
    assert_equal true, deleted["deleted"]
  end

  test "create_collection with an invalid field type is a validation tool error" do
    _, err = mcp_call(@rw, "create_collection", { name: "Bad", fields: [ { "label" => "X", "type" => "bogus" } ] })
    assert_match(/Validation failed/, err)
  end

  test "get_collection requires id or slug" do
    _, err = mcp_call(@rw, "get_collection", {})
    refute_nil err
  end

  test "get_collection not found is a tool error" do
    _, err = mcp_call(@rw, "get_collection", { id: 999_999 })
    assert_match(/not found/, err)
  end

  test "delete_collection with a published item requires the publish scope" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: fields)
    item = collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!

    _, err = mcp_call(@rw, "delete_collection", { id: collection.id })
    assert_match(/published items.*publish/, err)
    assert ActiveCanvas::Collection.exists?(collection.id)

    rwp = mcp_token(%w[read write publish])
    deleted, err2 = mcp_call(rwp, "delete_collection", { id: collection.id })
    assert_nil err2
    assert_equal true, deleted["deleted"]
  end

  test "list_collections' items_count and template page ids do not run one query per collection" do
    12.times do |i|
      collection = ActiveCanvas::Collection.create!(name: "Coll #{i}", slug: "coll-#{i}", fields: fields, has_pages: i.even?)
      2.times do |j|
        item = collection.items.new
        item.assign_fields("name" => "Item #{j}")
        item.save!
      end
    end

    result = nil
    query_count = count_sql_queries { result, = mcp_call(@rw, "list_collections", { limit: 50 }) }

    assert_equal Array.new(12, 2), result["items"].map { |i| i["items_count"] }
    has_pages_items = result["items"].select { |i| i["has_pages"] }
    assert_equal 6, has_pages_items.length
    has_pages_items.each do |i|
      refute_nil i["index_template_page_id"]
      refute_nil i["show_template_page_id"]
    end
    assert_operator query_count, :<=, 7, "expected a flat query count, not one query per collection"
  end

  test "create_collection and update_collection round trip the public-pages options" do
    created, err = mcp_call(@rw, "create_collection", {
      name: "Team", fields: fields, has_pages: true, per_page: 6, show_in_sidebar: true, title_field: "name"
    })
    assert_nil err
    assert_equal true, created["has_pages"]
    assert_equal 6, created["per_page"]
    assert_equal true, created["show_in_sidebar"]
    assert_equal "name", created["title_field"]
    assert_equal "/canvas/team", created["index_url"]
    refute_nil created["index_template_page_id"]
    refute_nil created["show_template_page_id"]

    updated, err2 = mcp_call(@rw, "update_collection", {
      id: created["id"], per_page: 9, show_in_sidebar: false, description_field: "bio"
    })
    assert_nil err2
    assert_equal 9, updated["per_page"]
    assert_equal false, updated["show_in_sidebar"]
    assert_equal "bio", updated["description_field"]
  end

  test "a collection without has_pages has no index_url or template page ids" do
    created, = mcp_call(@rw, "create_collection", { name: "Team", fields: fields })
    assert_equal false, created["has_pages"]
    refute created.key?("index_url")
    refute created.key?("index_template_page_id")
    refute created.key?("show_template_page_id")
  end

  test "update_collection's has_pages toggle requires the publish scope when the collection has published items" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: fields, has_pages: true)
    item = collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!

    _, err = mcp_call(@rw, "update_collection", { id: collection.id, has_pages: false })
    assert_match(/published items.*publish/, err)
    assert collection.reload.has_pages?

    rwp = mcp_token(%w[read write publish])
    updated, err2 = mcp_call(rwp, "update_collection", { id: collection.id, has_pages: false })
    assert_nil err2
    assert_equal false, updated["has_pages"]
  end

  test "update_collection's has_pages toggle does not require publish when the collection has no published items" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: fields)
    updated, err = mcp_call(@rw, "update_collection", { id: collection.id, has_pages: true })
    assert_nil err
    assert_equal true, updated["has_pages"]
  end

  test "collection write tools are not listed for a read-only token" do
    ro = mcp_token(%w[read])
    names = mcp_tool_names(ro)
    %w[create_collection update_collection delete_collection].each { |n| refute_includes names, n }
  end
end
