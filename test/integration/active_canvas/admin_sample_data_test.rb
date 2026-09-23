require "test_helper"

class ActiveCanvas::AdminSampleDataTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  def sample(binding, bindings)
    post "/canvas/admin/pages/#{@page.id}/sample_data",
      params: { binding: binding, bindings: bindings.to_json }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    JSON.parse(response.body)
  end

  test "returns the first rows of a collection binding with field names" do
    team = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
    %w[Ada Bob Cy Dee].each { |n| item = team.items.new; item.assign_fields("name" => n); item.save!; item.publish! }

    body = sample("team", { "team" => { "source" => "team", "params" => { "sort_field" => "name", "sort_dir" => "asc" } } })
    assert_response :success
    assert_equal 3, body["rows"].size
    assert_equal "Ada", body["rows"].first["name"]
    assert body["rows"].first.key?("id")
  end

  test "uses the unsaved bindings sent by the editor, not the saved ones" do
    body = sample("greeting", { "greeting" => { "source" => "_literal", "value" => "unsaved" } })
    assert_response :success
    assert_equal "unsaved", body["rows"]
  end

  test "returns 404 for a binding that is not defined" do
    body = sample("ghost", {})
    assert_response :not_found
    assert_match(/ghost/, body["error"])
  end

  test "returns 422 when the source fails" do
    ActiveCanvas::DataSources.register(:boom) { fetch { raise "db gone" } }
    body = sample("x", { "x" => { "source" => "boom" } })
    assert_response :unprocessable_entity
    assert_equal "db gone", body["error"]
  end
end
