require "test_helper"

class ActiveCanvas::CollectionItemPublishTest < ActiveSupport::TestCase
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" } ])
  end

  test "publish copies draft_data to data, sets status and timestamp" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!

    assert_equal "published", item.status
    assert_equal "Ada", item.data["name"]
    assert item.published_at.present?
  end

  test "publish writes a version snapshot" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!

    assert_difference "ActiveCanvas::CollectionItemVersion.count", 1 do
      item.publish!
    end
    version = item.versions.last
    assert_equal 1, version.version_number
    assert_equal({ "name" => "Ada" }, version.data)
  end

  test "successive publishes increment version_number" do
    item = @collection.items.create!
    item.assign_fields("name" => "A"); item.save!; item.publish!
    item.assign_fields("name" => "B"); item.save!; item.publish!
    assert_equal [ 1, 2 ], item.versions.order(:version_number).pluck(:version_number)
    assert_equal "B", item.reload.data["name"]
  end

  test "editing after publish keeps published data until republish" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada"); item.save!; item.publish!
    item.assign_fields("name" => "Grace"); item.save!

    assert_equal "Ada", item.data["name"]        # public snapshot unchanged
    assert_equal "Grace", item.draft_data["name"] # draft holds the edit
  end

  test "unpublish returns to draft" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada"); item.save!; item.publish!
    item.unpublish!
    assert_equal "draft", item.reload.status
  end

  test "status must be draft or published" do
    item = @collection.items.new
    item.status = "archived"
    assert_not item.valid?
  end

  test "publish records the current editor on the version" do
    ActiveCanvas::CollectionItem.current_editor = "alice@example.com"
    item = @collection.items.new
    item.assign_fields("name" => "Ada"); item.save!; item.publish!
    assert_equal "alice@example.com", item.versions.last.changed_by
  ensure
    ActiveCanvas::CollectionItem.current_editor = nil
  end

  test "publish re-sanitizes rich_text that was written around assign_fields" do
    rich = ActiveCanvas::Collection.create!(name: "Rich", slug: "rich", fields: [ { "label" => "Body", "type" => "rich_text" } ])
    item = rich.items.create!(draft_data: { "body" => "<p>ok</p><script>alert(1)</script>" })
    item.publish!
    assert_includes item.reload.data["body"], "<p>ok</p>"
    refute_includes item.data["body"], "<script>"
  end

  test "publish drops keys that are not in the schema" do
    item = @collection.items.create!(draft_data: { "name" => "Ada", "ghost" => "x" })
    item.publish!
    assert_equal({ "name" => "Ada" }, item.reload.data)
  end

  test "publish refuses when a required field is blank" do
    strict = ActiveCanvas::Collection.create!(name: "Strict", slug: "strict",
      fields: [ { "label" => "Name", "type" => "text", "required" => true }, { "label" => "Bio", "type" => "text" } ])
    item = strict.items.create!(draft_data: { "bio" => "x" })

    assert_not item.publish
    assert_includes item.errors.full_messages.join, "Name"
    assert_equal "draft", item.reload.status
    assert_equal 0, item.versions.count
    assert_raises(ActiveRecord::RecordInvalid) { item.publish! }
  end

  test "a required boolean never blocks publishing" do
    strict = ActiveCanvas::Collection.create!(name: "Strict", slug: "strict",
      fields: [ { "label" => "Active", "type" => "boolean", "required" => true } ])
    item = strict.items.create!(draft_data: { "active" => false })
    assert item.publish
  end

  test "pending_changes? compares draft and published data on schema fields only" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada"); item.save!
    assert item.pending_changes?
    item.publish!
    assert_not item.reload.pending_changes?
    item.assign_fields("name" => "Grace"); item.save!
    assert item.pending_changes?
  end

  test "publish normalizes the draft so nothing is pending afterwards" do
    rich = ActiveCanvas::Collection.create!(name: "Rich", slug: "rich", fields: [ { "label" => "Body", "type" => "rich_text" }, { "label" => "N", "type" => "number" } ])
    item = rich.items.create!(draft_data: { "body" => "<p>ok</p><script>x</script>", "n" => 3.5, "ghost" => 1 })
    item.publish!
    item.reload
    assert_equal item.data, item.draft_data
    assert_equal 3.5, item.data["n"]
    assert_not item.pending_changes?
  end
end
