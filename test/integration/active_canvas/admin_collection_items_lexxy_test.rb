require "test_helper"

class ActiveCanvas::AdminCollectionItemsLexxyTest < ActionDispatch::IntegrationTest
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Rich", slug: "rich",
      fields: [ { "label" => "Body", "type" => "rich_text" } ])
  end

  test "the item form loads a lexxy-editor plus its module script and stylesheet for a rich_text field" do
    get "/canvas/admin/collections/#{@collection.id}/items/new"

    assert_response :success
    assert_select "lexxy-editor[name=?]", "item[data][body]"
    assert_select "script[type=module][src*=?]", "lexxy"
    assert_select "link[rel=stylesheet][href*=?]", "lexxy"
  end

  test "the item form provides an import map for Lexxy's @rails/activestorage bare import" do
    get "/canvas/admin/collections/#{@collection.id}/items/new"

    assert_response :success
    assert_select "script[type=importmap]", text: /@rails\/activestorage/
  end

  test "a host-app form using form.rich_text_area renders native ActionText/Trix, not Lexxy (host isolation)" do
    get "/host/rich_text_form"

    assert_response :success
    assert_select "trix-editor"
    assert_select "lexxy-editor", count: 0
  end
end
