require "test_helper"

class ActiveCanvas::AdminCollectionItemsTest < ActionDispatch::IntegrationTest
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Active", "type" => "boolean" } ])
  end

  def add_item(name:, active: true, publish: false)
    item = @collection.items.new
    item.assign_fields("name" => name, "active" => active)
    item.save!
    item.publish! if publish
    item
  end

  test "index shows a grid with a column per leading field and a status badge" do
    add_item(name: "Ada", publish: true)
    add_item(name: "Grace", publish: false)

    get "/canvas/admin/collections/#{@collection.id}/items"

    assert_response :success
    assert_includes response.body, "Name"     # header
    assert_includes response.body, "Ada"
    assert_includes response.body, "Grace"
    assert_select ".badge-success"            # published badge
    assert_select ".badge-gray"               # draft badge
  end

  test "index filters by status" do
    add_item(name: "Ada", publish: true)
    add_item(name: "Grace", publish: false)

    get "/canvas/admin/collections/#{@collection.id}/items", params: { status: "published" }

    assert_includes response.body, "Ada"
    refute_includes response.body, "Grace"
  end

  test "index shows an empty state with no items" do
    get "/canvas/admin/collections/#{@collection.id}/items"
    assert_response :success
    assert_select ".empty-state"
  end

  test "new renders one input per schema field with the right names" do
    get "/canvas/admin/collections/#{@collection.id}/items/new"
    assert_response :success
    assert_select "input[name=?]", "item[data][name]"          # text field
    assert_select "input[type=checkbox][name=?]", "item[data][active]"
  end

  test "create coerces submitted values into draft_data per type" do
    assert_difference "ActiveCanvas::CollectionItem.count", 1 do
      post "/canvas/admin/collections/#{@collection.id}/items",
        params: { item: { slug: "ada", data: { "name" => "Ada", "active" => "1" } } }
    end
    item = ActiveCanvas::CollectionItem.last
    assert_equal "Ada", item.draft_data["name"]
    assert_equal true, item.draft_data["active"]
    assert_equal "draft", item.status
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "create renders every widget type without error" do
    rich = ActiveCanvas::Collection.create!(name: "Rich", slug: "rich", fields: [
      { "label" => "Body", "type" => "rich_text" },
      { "label" => "Count", "type" => "number" },
      { "label" => "When", "type" => "date" },
      { "label" => "Pick", "type" => "select", "options" => %w[a b] },
      { "label" => "Photo", "type" => "media" }
    ])
    get "/canvas/admin/collections/#{rich.id}/items/new"
    assert_response :success
    assert_select "lexxy-editor[name=?]", "item[data][body]"    # rich_text: Lexxy, not a plain textarea (see admin_collection_items_lexxy_test.rb)
    assert_select "input[type=number][name=?]", "item[data][count]"
    assert_select "input[type=date][name=?]", "item[data][when]"
    assert_select "select[name=?]", "item[data][pick]"
    assert_select "select[name=?]", "item[data][photo]"
  end

  test "edit pre-fills widgets from draft_data" do
    item = add_item(name: "Ada", active: true)
    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
    assert_response :success
    assert_select "input[name=?][value=?]", "item[data][name]", "Ada"
  end

  test "update merges new values into draft_data non-destructively" do
    item = add_item(name: "Ada", active: true)
    patch "/canvas/admin/collections/#{@collection.id}/items/#{item.id}",
      params: { item: { data: { "name" => "Ada Lovelace" } } }
    item.reload
    assert_equal "Ada Lovelace", item.draft_data["name"]
    assert_equal true, item.draft_data["active"]   # untouched key preserved
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "create with a scalar item data param does not 500" do
    assert_nothing_raised do
      post "/canvas/admin/collections/#{@collection.id}/items", params: { item: { data: "oops" } }
    end
    assert_not_equal 500, response.status
  end

  test "destroy removes the item" do
    item = add_item(name: "Ada")
    assert_difference "ActiveCanvas::CollectionItem.count", -1 do
      delete "/canvas/admin/collections/#{@collection.id}/items/#{item.id}"
    end
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items"
  end

  test "publish copies draft to data, sets published_at and writes a version" do
    item = add_item(name: "Ada", active: true)
    assert_difference "ActiveCanvas::CollectionItemVersion.count", 1 do
      patch "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/publish"
    end
    item.reload
    assert_equal "published", item.status
    assert_equal "Ada", item.data["name"]
    assert_not_nil item.published_at
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "unpublish returns the item to draft" do
    item = add_item(name: "Ada", publish: true)
    patch "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/unpublish"
    assert_equal "draft", item.reload.status
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "history lists versions newest first with snapshot content and no restore control" do
    item = add_item(name: "Ada")
    item.publish!
    item.assign_fields("name" => "Grace Hopper"); item.save!
    item.publish!

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/history"

    assert_response :success
    body = response.body
    assert_operator body.index("Version 2"), :<, body.index("Version 1")   # newest first
    assert_includes body, "Grace Hopper"   # newer snapshot
    assert_includes body, "Ada"            # older snapshot (distinct, not a substring)
    refute_match(/restore/i, body)
  end

  test "publish with a blank required field redirects back with an alert" do
    strict = ActiveCanvas::Collection.create!(name: "Strict", slug: "strict",
      fields: [ { "label" => "Name", "type" => "text", "required" => true } ])
    item = strict.items.create!(draft_data: {})
    patch "/canvas/admin/collections/#{strict.id}/items/#{item.id}/publish"
    assert_redirected_to "/canvas/admin/collections/#{strict.id}/items/#{item.id}/edit"
    assert_match(/Name/, flash[:alert])
    assert_equal "draft", item.reload.status
  end

  test "edit prefills every widget type from draft_data" do
    media = ActiveCanvas::Media.new
    media.file.attach(io: StringIO.new("x"), filename: "pic.png", content_type: "image/png")
    media.save!
    rich = ActiveCanvas::Collection.create!(name: "Rich", slug: "rich", fields: [
      { "label" => "Body", "type" => "rich_text" },
      { "label" => "Count", "type" => "number" },
      { "label" => "When", "type" => "date" },
      { "label" => "Pick", "type" => "select", "options" => %w[a b] },
      { "label" => "Photo", "type" => "media" },
      { "label" => "On", "type" => "boolean" }
    ])
    item = rich.items.new
    item.assign_fields("body" => "<p>hi</p>", "count" => "7", "when" => "2026-07-02", "pick" => "b", "photo" => media.id, "on" => "1")
    item.save!

    get "/canvas/admin/collections/#{rich.id}/items/#{item.id}/edit"
    assert_response :success
    assert_select "lexxy-editor[name=?][value=?]", "item[data][body]", "<p>hi</p>"    # rich_text: Lexxy (see admin_collection_items_lexxy_test.rb)
    assert_select "input[type=number][name=?][value=?]", "item[data][count]", "7"
    assert_select "input[type=date][name=?][value=?]", "item[data][when]", "2026-07-02"
    assert_select "select[name=?] option[selected][value=?]", "item[data][pick]", "b"
    assert_select "select[name=?] option[selected][value=?]", "item[data][photo]", media.id.to_s
    assert_select "input[type=checkbox][name=?][checked]", "item[data][on]"
  end

  test "the grid shows the published value for published rows and the draft for drafts" do
    published = add_item(name: "Ada", publish: true)
    published.assign_fields("name" => "Ada (edited)"); published.save!
    add_item(name: "Grace", publish: false)

    get "/canvas/admin/collections/#{@collection.id}/items"
    assert_includes response.body, "Ada"
    refute_includes response.body, "Ada (edited)"
    assert_includes response.body, "Grace"
  end

  test "the field builder shows each field id" do
    get "/canvas/admin/collections/#{@collection.id}/edit"
    assert_select "template#ac-field-row-template code[data-field-id-display]"
    assert_includes css_select("script#ac-fields-data").first.content, "\"id\":\"name\""
  end

  test "edit offers Publish changes and Unpublish for a published item with pending edits" do
    item = add_item(name: "Ada", publish: true)
    item.assign_fields("name" => "Grace"); item.save!
    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/publish"
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/unpublish"
    assert_includes response.body, "Publish changes"
    assert_includes response.body, "draft changes that visitors do not see yet"
  end

  test "edit offers only Unpublish for a published item without pending edits" do
    item = add_item(name: "Ada", publish: true)
    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/publish", count: 0
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/unpublish"
  end

  test "edit offers Publish for a draft" do
    item = add_item(name: "Ada")
    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/publish"
    refute_includes response.body, "Publish changes"
  end

  test "the grid badges pending changes and offers every row action" do
    published = add_item(name: "Ada", publish: true)
    published.assign_fields("name" => "Grace"); published.save!
    draft = add_item(name: "Bob")

    get "/canvas/admin/collections/#{@collection.id}/items"
    assert_select ".badge-warning", text: /draft changes/i
    assert_select "a[href=?]", "/canvas/admin/collections/#{@collection.id}/items/#{published.id}/history"
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{published.id}/unpublish"
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{published.id}/publish"
    assert_select "form[action=?]", "/canvas/admin/collections/#{@collection.id}/items/#{draft.id}/publish"
    assert_select "form[action=?][method=post] input[name=_method][value=delete]", "/canvas/admin/collections/#{@collection.id}/items/#{draft.id}"
  end

  test "the SEO fieldset is hidden when the collection has no pages" do
    get "/canvas/admin/collections/#{@collection.id}/items/new"
    assert_response :success
    assert_select "#ac-item-seo", count: 0
  end

  test "the SEO fieldset renders with the media select + preview when the collection has_pages" do
    @collection.update!(has_pages: true)
    get "/canvas/admin/collections/#{@collection.id}/items/new"
    assert_response :success
    assert_select "#ac-item-seo"
    assert_select "input[name=?]", "item[data][_seo][meta_title]"
    assert_select "textarea[name=?]", "item[data][_seo][meta_description]"
    assert_select "select[name=?][data-media-select]", "item[data][_seo][og_image_media_id]"
  end

  test "the item slug is marked required when has_pages" do
    @collection.update!(has_pages: true)
    get "/canvas/admin/collections/#{@collection.id}/items/new"
    assert_includes response.body, "Item slug</label>"
  end

  test "create persists _seo and generates a slug when has_pages" do
    @collection.update!(has_pages: true, title_field: "name")

    assert_difference "ActiveCanvas::CollectionItem.count", 1 do
      post "/canvas/admin/collections/#{@collection.id}/items", params: {
        item: { data: { "name" => "Ada Lovelace",
          "_seo" => { "meta_title" => "  Custom title  ", "meta_description" => "desc" } } }
      }
    end

    item = ActiveCanvas::CollectionItem.last
    assert_equal "ada-lovelace", item.slug
    assert_equal "Custom title", item.draft_data["_seo"]["meta_title"]
    assert_equal "desc", item.draft_data["_seo"]["meta_description"]
  end

  test "edit pre-fills the SEO fieldset from draft_data" do
    @collection.update!(has_pages: true)
    item = @collection.items.new
    item.assign_fields("name" => "Ada", "_seo" => { "meta_title" => "T", "meta_description" => "D" })
    item.save!

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
    assert_response :success
    assert_select "input[name=?][value=?]", "item[data][_seo][meta_title]", "T"
    assert_select "textarea[name=?]", "item[data][_seo][meta_description]", text: "D"
  end

  test "history keeps showing a field that was removed from the schema" do
    item = add_item(name: "Ada", active: true)
    item.publish!
    @collection.update!(fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/history"
    assert_response :success
    assert_select "dt", text: /\Aactive\s*\(removed field\)/   # raw id, label is gone
    assert_select "dd", text: "true"
  end

  test "items page links to the index/item templates and the public page when the collection has pages" do
    @collection.update!(has_pages: true)
    index_template = @collection.template_pages.find_by!(collection_role: "index")
    show_template = @collection.template_pages.find_by!(collection_role: "show")

    get "/canvas/admin/collections/#{@collection.id}/items"

    assert_response :success
    assert_select "a[href=?]", "/canvas/admin/pages/#{index_template.id}/editor", text: "Design index page"
    assert_select "a[href=?]", "/canvas/admin/pages/#{show_template.id}/editor", text: "Design item page"
    assert_select "a[href=?]", "/canvas/team", text: "View public page"
  end

  test "items page shows no template links when the collection has no public pages" do
    get "/canvas/admin/collections/#{@collection.id}/items"

    assert_response :success
    assert_select "a", text: "Design index page", count: 0
    assert_select "a", text: "View public page", count: 0
  end
end
