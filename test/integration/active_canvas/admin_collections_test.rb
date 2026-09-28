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
    assert_select "input[name=?]", "collection[fields_json]"
  end

  test "create parses the fields JSON, generates ids and redirects" do
    fields = [ { "label" => "Full Name", "type" => "text", "required" => true, "options" => [] },
               { "label" => "Bio", "type" => "textarea", "required" => false, "options" => [] } ].to_json

    assert_difference "ActiveCanvas::Collection.count", 1 do
      post "/canvas/admin/collections", params: { collection: { name: "Team", slug: "team", fields_json: fields } }
    end

    collection = ActiveCanvas::Collection.last
    assert_equal %w[full_name bio], collection.fields.map { |f| f["id"] }
    assert_equal "text", collection.fields.first["type"]
    assert_redirected_to "/canvas/admin/collections/#{collection.id}/edit"
  end

  test "create with malformed fields JSON re-renders 422 without raising" do
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields_json: "{not json" } }
    end
    assert_response :unprocessable_entity
  end

  test "create with a non-array fields payload re-renders 422 without raising" do
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields_json: '{"a":1}' } }
    end
    assert_response :unprocessable_entity
  end

  test "create with a scalar fields payload re-renders 422 without raising" do
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields_json: "42" } }
    end
    assert_response :unprocessable_entity
  end

  test "create with an invalid schema surfaces a validation error" do
    bad = [ { "label" => "", "type" => "text", "options" => [] } ].to_json
    assert_no_difference "ActiveCanvas::Collection.count" do
      post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields_json: bad } }
    end
    assert_response :unprocessable_entity
    assert_select ".error-messages"
  end

  test "create with an array fields param does not 500 and stores no fields" do
    post "/canvas/admin/collections", params: { collection: { name: "X", slug: "x", fields_json: [ "1" ] } }
    assert_not_equal 500, response.status
    collection = ActiveCanvas::Collection.find_by(slug: "x")
    assert_equal [], collection.fields if collection
  end

  test "update with an array fields param does not 500 and keeps the existing fields" do
    collection = create_collection
    patch "/canvas/admin/collections/#{collection.id}", params: { collection: { name: "X", slug: "x", fields_json: [ "1" ] } }
    assert_not_equal 500, response.status
    assert_equal %w[name], collection.reload.fields.map { |f| f["id"] }
  end

  test "a field label that tries to break out of the data script is escaped" do
    collection = create_collection(fields: [ { "label" => "</script><img src=x onerror=alert(1)>", "type" => "text" } ])
    get "/canvas/admin/collections/#{collection.id}/edit"
    assert_response :success
    refute_includes response.body, "</script><img src=x onerror=alert(1)>"
    assert_includes response.body, "\\u003c/script\\u003e"
  end

  test "edit pre-populates the fields data script for the JS to render" do
    collection = create_collection(fields: [ { "label" => "Name", "type" => "text" } ])
    get "/canvas/admin/collections/#{collection.id}/edit"
    assert_response :success
    data = css_select("script#ac-fields-data").first.content
    assert_includes data, "\"id\":\"name\""
  end

  test "update renames a label without changing the field id" do
    collection = create_collection(fields: [ { "label" => "Name", "type" => "text" } ])
    original_id = collection.fields.first["id"]
    fields = [ { "id" => original_id, "label" => "Full Name", "type" => "text", "required" => false, "options" => [] } ].to_json

    patch "/canvas/admin/collections/#{collection.id}",
      params: { collection: { name: "Team", slug: "team", fields_json: fields } }

    collection.reload
    assert_equal original_id, collection.fields.first["id"]
    assert_equal "Full Name", collection.fields.first["label"]
    assert_redirected_to "/canvas/admin/collections/#{collection.id}/edit"
  end

  test "destroy removes the collection and its items" do
    collection = create_collection
    collection.items.create!(status: "draft")
    assert_difference "ActiveCanvas::Collection.count", -1 do
      delete "/canvas/admin/collections/#{collection.id}"
    end
    assert_redirected_to "/canvas/admin/collections"
  end

  test "the admin chrome shows a Collections nav link" do
    get "/canvas/admin/collections"
    assert_select "nav a[href=?]", "/canvas/admin/collections"
  end

  test "new renders selects for title, description and image field" do
    get "/canvas/admin/collections/new"
    assert_response :success
    assert_select "select[name=?]", "collection[title_field]"
    assert_select "select[name=?]", "collection[description_field]"
    assert_select "select[name=?]", "collection[image_field]"
    assert_select "input[type=checkbox][name=?]", "collection[has_pages]"
    assert_select "input[type=checkbox][name=?]", "collection[show_in_sidebar]"
  end

  test "create persists has_pages, per_page, show_in_sidebar and the field references" do
    fields = [ { "label" => "Name", "type" => "text" }, { "label" => "Photo", "type" => "media" } ].to_json

    post "/canvas/admin/collections", params: { collection: {
      name: "Team", slug: "team", fields_json: fields,
      has_pages: "1", per_page: "24", show_in_sidebar: "1",
      title_field: "name", description_field: "name", image_field: "photo"
    } }

    collection = ActiveCanvas::Collection.last
    assert_equal true, collection.has_pages
    assert_equal 24, collection.per_page
    assert_equal true, collection.show_in_sidebar
    assert_equal "name", collection.title_field
    assert_equal "name", collection.description_field
    assert_equal "photo", collection.image_field
  end

  test "edit pre-selects the current field references and checkbox state" do
    collection = create_collection(fields: [ { "label" => "Name", "type" => "text" } ])
    collection.update!(has_pages: true, show_in_sidebar: true, title_field: "name")

    get "/canvas/admin/collections/#{collection.id}/edit"
    assert_response :success
    assert_select "input[type=checkbox][name=?][checked]", "collection[has_pages]"
    assert_select "input[type=checkbox][name=?][checked]", "collection[show_in_sidebar]"
    assert_select "select[name=?] option[selected][value=?]", "collection[title_field]", "name"
  end

  test "edit shows Design index/item page buttons once has_pages is on" do
    collection = create_collection
    collection.update!(has_pages: true)
    index_page = collection.template_pages.find_by(collection_role: "index")
    show_page = collection.template_pages.find_by(collection_role: "show")

    get "/canvas/admin/collections/#{collection.id}/edit"

    assert_response :success
    assert_select "a[href=?]", "/canvas/admin/pages/#{index_page.id}/editor", text: "Design index page"
    assert_select "a[href=?]", "/canvas/admin/pages/#{show_page.id}/editor", text: "Design item page"
  end

  test "edit does not show Design page buttons when has_pages is off" do
    collection = create_collection

    get "/canvas/admin/collections/#{collection.id}/edit"

    assert_response :success
    assert_no_match(/Design index page|Design item page/, response.body)
  end

  test "update rejects a has_pages slug that collides with a reserved path" do
    collection = create_collection

    patch "/canvas/admin/collections/#{collection.id}", params: { collection: { name: "Team", slug: "admin", has_pages: "1" } }

    assert_response :unprocessable_entity
    assert_select ".error-messages"
  end

  test "the sidebar lists only show_in_sidebar collections, ordered by name, and highlights the active one" do
    shown = create_collection(name: "Blog", slug: "blog")
    shown.update!(show_in_sidebar: true)
    also_shown = create_collection(name: "Authors", slug: "authors")
    also_shown.update!(show_in_sidebar: true)
    hidden = create_collection(name: "Hidden", slug: "hidden")

    get "/canvas/admin/collections/#{shown.id}/items"

    assert_response :success
    assert_select "nav a[href=?].active", "/canvas/admin/collections/#{shown.id}/items"
    assert_select "nav a[href=?]", "/canvas/admin/collections/#{also_shown.id}/items"
    assert_select "nav a[href=?]", "/canvas/admin/collections/#{hidden.id}/items", count: 0
    assert_select "nav a[href=?].active", "/canvas/admin/collections", count: 0

    body = response.body
    assert_operator body.index("Authors"), :<, body.index("Blog")
  end

  test "the generic Collections link stays active for a collection with no sidebar entry" do
    hidden = create_collection(name: "Hidden", slug: "hidden")

    get "/canvas/admin/collections/#{hidden.id}/items"

    assert_response :success
    assert_select "nav a[href=?].active", "/canvas/admin/collections"
  end
end
