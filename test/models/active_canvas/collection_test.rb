require "test_helper"

class ActiveCanvas::CollectionTest < ActiveSupport::TestCase
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "valid with name, slug and fields" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team", fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    assert collection.valid?
  end

  test "requires name and slug" do
    assert_not ActiveCanvas::Collection.new(slug: "team").valid?
    assert_not ActiveCanvas::Collection.new(name: "Team").valid?
  end

  test "slug is unique" do
    ActiveCanvas::Collection.create!(name: "Team", slug: "team")
    assert_not ActiveCanvas::Collection.new(name: "Team 2", slug: "team").valid?
  end

  test "slug is parameterized on save" do
    collection = ActiveCanvas::Collection.create!(name: "Our Team", slug: "Our Team!")
    assert_equal "our-team", collection.slug
  end

  test "slug may not collide with a registered data source" do
    ActiveCanvas::DataSources.reset_for_testing!
    ActiveCanvas::DataSources.register(:events) { fetch { [] } }
    collection = ActiveCanvas::Collection.new(name: "Events", slug: "events")
    assert_not collection.valid?
    assert_includes collection.errors[:slug].join, "reserved"
  end

  test "slug may not be a reserved word" do
    assert_not ActiveCanvas::Collection.new(name: "L", slug: "_literal").valid?
  end

  test "missing field ids are derived from labels on save" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Full Name", "type" => "text" }, { "label" => "Job Title", "type" => "text" } ])
    assert_equal %w[full_name job_title], collection.fields.map { |f| f["id"] }
  end

  test "derived field ids are made unique" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Name", "type" => "text" } ])
    assert_equal %w[name name_2], collection.fields.map { |f| f["id"] }
  end

  test "existing field ids are preserved" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "id" => "custom_key", "label" => "Renamed", "type" => "text" } ])
    assert_equal %w[custom_key], collection.fields.map { |f| f["id"] }
  end

  test "destroying a collection destroys its items" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team")
    collection.items.create!(status: "draft")
    collection.destroy
    assert_equal 0, ActiveCanvas::CollectionItem.count
  end
end
