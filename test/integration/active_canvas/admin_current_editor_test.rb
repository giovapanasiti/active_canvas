require "test_helper"

class ActiveCanvas::AdminCurrentEditorTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "a")
    ActiveCanvas::Admin::ApplicationController.class_eval do
      define_method(:active_canvas_current_user) { "editor@example.com" }
    end
  end

  teardown do
    ActiveCanvas::Admin::ApplicationController.class_eval { remove_method(:active_canvas_current_user) }
  end

  test "saving from the editor attributes the page version to the current user" do
    patch "/canvas/admin/pages/#{@page.id}/save_editor",
      params: { page: { content: "b" } }, headers: { "Accept" => "application/json" }
    assert_response :success
    assert_equal "editor@example.com", @page.versions.last.changed_by
  end

  test "publishing an item attributes the version to the current user" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
    item = collection.items.new
    item.assign_fields("name" => "Ada"); item.save!
    patch "/canvas/admin/collections/#{collection.id}/items/#{item.id}/publish"
    assert_equal "editor@example.com", item.reload.versions.last.changed_by
  end
end
