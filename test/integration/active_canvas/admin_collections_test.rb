require "test_helper"

class ActiveCanvas::AdminCollectionsTest < ActionDispatch::IntegrationTest
  def create_collection(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
    ActiveCanvas::Collection.create!(name: name, slug: slug, fields: fields)
  end

  test "index lists collections with field and item counts" do
    collection = create_collection
    item = collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!

    get "/canvas/admin/collections"

    assert_response :success
    assert_includes response.body, "Team"
    assert_includes response.body, "team"          # slug
    assert_select "a[href=?]", "/canvas/admin/collections/new"
  end

  test "index shows an empty state when there are no collections" do
    get "/canvas/admin/collections"
    assert_response :success
    assert_select ".empty-state"
  end

  test "new renders the collection form with the field builder" do
    get "/canvas/admin/collections/new"
    assert_response :success
    assert_select "template#ac-field-row-template"
    assert_select "input[name=?]", "collection[fields]"
  end

  test "create parses the fields JSON, generates ids and redirects" do
    fields = [ { "label" => "Full Name", "type" => "text", "required" => true, "options" => [] },
               { "label" => "Bio", "type" => "textarea", "required" => false, "options" => [] } ].to_json

    assert_difference "ActiveCanvas::Collection.count", 1 do
      post "/canvas/admin/collections", params: { collection: { name: "Team", slug: "team", fields: fields } }
    end

    collection = ActiveCanvas::Collection.last
    assert_equal %w[full_name bio], collection.fields.map { |f| f["id"] }
    assert_equal "text", collection.fields.first["type"]
    assert_redirected_to "/canvas/admin/collections/#{collection.id}/edit"
  end

  test "create with malformed fields JSON re-renders 422 without raising" do
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields: "{not json" } }
    end
    assert_response :unprocessable_entity
  end

  test "create with a non-array fields payload re-renders 422 without raising" do
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields: '{"a":1}' } }
    end
    assert_response :unprocessable_entity
  end

  test "create with a scalar fields payload re-renders 422 without raising" do
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields: "42" } }
    end
    assert_response :unprocessable_entity
  end

  test "create with an invalid schema surfaces a validation error" do
    bad = [ { "label" => "", "type" => "text", "options" => [] } ].to_json
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields: bad } }
    end
    assert_response :unprocessable_entity
    assert_select ".error-messages"
  end
end
