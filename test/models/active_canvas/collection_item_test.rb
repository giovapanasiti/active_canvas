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

  test "slug is optional when the collection has no pages" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    assert item.valid?
  end

  test "slug is required and generated from title_field when the collection has_pages" do
    @collection.update!(has_pages: true, title_field: "name")
    item = @collection.items.new
    item.assign_fields("name" => "Ada Lovelace")
    item.save!
    assert_equal "ada-lovelace", item.slug
  end

  test "slug generation falls back to item-<n> without a title value" do
    @collection.update!(has_pages: true)
    item = @collection.items.create!
    assert_equal "item-1", item.slug
  end

  test "generate_slug de-duplicates with -2, -3, ..." do
    @collection.update!(has_pages: true, title_field: "name")
    first = @collection.items.new; first.assign_fields("name" => "Ada"); first.save!
    second = @collection.items.new; second.assign_fields("name" => "Ada"); second.save!
    third = @collection.items.new; third.assign_fields("name" => "Ada"); third.save!
    assert_equal %w[ada ada-2 ada-3], [ first, second, third ].map(&:slug)
  end

  test "slug must be unique within the collection" do
    @collection.update!(has_pages: true)
    @collection.items.create!(slug: "dupe")
    other = @collection.items.new(slug: "dupe")
    assert_not other.valid?
    assert_includes other.errors[:slug].join, "taken"
  end

  test "the same slug is allowed across different collections" do
    @collection.update!(has_pages: true)
    other_collection = ActiveCanvas::Collection.create!(name: "Other", slug: "other", has_pages: true)
    @collection.items.create!(slug: "dupe")
    item = other_collection.items.new(slug: "dupe")
    assert item.valid?
  end

  test "an entered slug is normalized to parameterize format" do
    @collection.update!(has_pages: true)
    item = @collection.items.create!(slug: "Not A Slug!")
    assert_equal "not-a-slug", item.slug
  end

  test "seo reads meta_title, meta_description and og_image_media_id from effective_data" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada", "_seo" => { "meta_title" => "T", "meta_description" => "D" })
    item.save!
    assert_equal({ "meta_title" => "T", "meta_description" => "D", "og_image_media_id" => nil }, item.seo)
  end

  test "seo is empty when there is no _seo data" do
    item = @collection.items.create!
    assert_equal({ "meta_title" => nil, "meta_description" => nil, "og_image_media_id" => nil }, item.seo)
  end

  test "_seo trims strings and drops an unknown media id" do
    item = @collection.items.new
    item.assign_fields("_seo" => { "meta_title" => "  Hi  ", "og_image_media_id" => "999999" })
    assert_equal "Hi", item.draft_data["_seo"]["meta_title"]
    assert_nil item.draft_data["_seo"]["og_image_media_id"]
  end

  test "_seo survives publish into data" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada", "_seo" => { "meta_title" => "T" })
    item.save!
    item.publish!
    assert_equal "T", item.data["_seo"]["meta_title"]
  end
end
