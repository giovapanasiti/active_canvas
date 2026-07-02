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
end
