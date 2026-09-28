require "test_helper"

class ActiveCanvas::AdminCollectionItemPreviewTest < ActionDispatch::IntegrationTest
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true,
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ], title_field: "name")
  end

  def add_item(name:, publish: false)
    item = @collection.items.new
    item.assign_fields("name" => name)
    item.save!
    item.publish! if publish
    item
  end

  test "preview shows the item's draft values, even when published" do
    item = add_item(name: "Ada", publish: true)
    item.assign_fields("name" => "Ada (draft edit)")
    item.save!

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/preview"
    assert_response :success
    assert_includes response.body, "Ada (draft edit)"
  end

  test "preview is available for a draft-only item" do
    item = add_item(name: "Grace", publish: false)

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/preview"
    assert_response :success
    assert_includes response.body, "Grace"
  end

  test "preview sets noindex" do
    item = add_item(name: "Ada", publish: true)

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/preview"
    assert_includes response.body, %(<meta name="robots" content="noindex">)
  end

  test "preview sets Cache-Control: no-store" do
    item = add_item(name: "Ada", publish: true)

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/preview"
    assert_match(/no-store/, response.headers["Cache-Control"].to_s)
  end

  test "the edit page and the items grid link to the preview" do
    item = add_item(name: "Ada", publish: true)
    preview_path = "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/preview"

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
    assert_select "a[href=?]", preview_path

    get "/canvas/admin/collections/#{@collection.id}/items"
    assert_select "a[href=?]", preview_path
  end

  test "preview goes through the admin authentication before_action" do
    item = add_item(name: "Ada", publish: true)

    with_config(authenticate_admin: -> { render plain: "nope", status: :forbidden }) do
      get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/preview"
      assert_response :forbidden
    end
  end
end
