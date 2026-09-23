require "test_helper"

class ActiveCanvas::CollectionItemTest < ActiveSupport::TestCase
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Bio", "type" => "rich_text" }, { "label" => "Age", "type" => "number" } ])
  end

  test "defaults to draft with empty data" do
    item = @collection.items.create!
    assert_equal "draft", item.status
    assert_equal({}, item.data)
    assert_equal({}, item.draft_data)
  end

  test "assign_fields coerces raw input into draft_data by field id" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada", "age" => "36", "unknown" => "x")
    assert_equal "Ada", item.draft_data["name"]
    assert_equal 36, item.draft_data["age"]
    assert_nil item.draft_data["unknown"]
  end

  test "assign_fields sanitizes rich_text" do
    item = @collection.items.new
    item.assign_fields("bio" => "<p>hi</p><script>x</script>")
    assert_includes item.draft_data["bio"], "<p>hi</p>"
    refute_includes item.draft_data["bio"], "<script>"
  end

  test "published scope returns only published items" do
    @collection.items.create!(status: "draft")
    published = @collection.items.create!(status: "published")
    assert_equal [ published ], @collection.items.published.to_a
  end

  test "assign_fields preserves fields absent from raw" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    item.assign_fields("age" => "36")
    assert_equal "Ada", item.draft_data["name"] # not clobbered by the second call
    assert_equal 36, item.draft_data["age"]
  end

  test "effective_data is the published snapshot for published items and the draft otherwise" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada"); item.save!
    assert_equal "Ada", item.effective_data["name"]
    item.publish!
    item.assign_fields("name" => "Grace"); item.save!
    assert_equal "Ada", item.effective_data["name"]
    item.unpublish!
    assert_equal "Grace", item.effective_data["name"]
  end
end
