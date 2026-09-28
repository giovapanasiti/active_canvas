require "test_helper"

class ActiveCanvas::CollectionSourceTest < ActiveSupport::TestCase
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Rank", "type" => "number" }, { "label" => "Dept", "type" => "text" } ])
    @a = publish("Ada", 2, "eng")
    @b = publish("Bob", 1, "eng")
    @c = publish("Cy", 3, "sales")
    @draft = @collection.items.new
    @draft.assign_fields("name" => "Draft"); @draft.save! # stays draft
  end

  def publish(name, rank, dept)
    item = @collection.items.new
    item.assign_fields("name" => name, "rank" => rank, "dept" => dept)
    item.save!; item.publish!
    item
  end

  def resolve(params = {})
    ActiveCanvas::CollectionSource.new(@collection).resolve(params)
  end

  test "returns only published items as hashes" do
    result = resolve
    assert_equal 3, result.size
    assert(result.all? { |row| row.is_a?(Hash) })
    refute_includes result.map { |r| r["name"] }, "Draft"
  end

  test "each hash carries id, slug, published_at and field values" do
    row = resolve.find { |r| r["name"] == "Ada" }
    assert_equal @a.id, row["id"]
    assert row.key?("published_at")
    assert_equal 2, row["rank"]
  end

  test "sort by field ascending and descending" do
    asc = resolve("sort_field" => "rank", "sort_dir" => "asc").map { |r| r["name"] }
    assert_equal %w[Bob Ada Cy], asc
    desc = resolve("sort_field" => "rank", "sort_dir" => "desc").map { |r| r["name"] }
    assert_equal %w[Cy Ada Bob], desc
  end

  test "unknown sort field falls back to published_at desc" do
    names = resolve("sort_field" => "nope").map { |r| r["name"] }
    assert_equal %w[Cy Bob Ada], names # newest first
  end

  test "equality filter on a field" do
    names = resolve("filter_field" => "dept", "filter_value" => "eng").map { |r| r["name"] }.sort
    assert_equal %w[Ada Bob], names
  end

  test "limit caps the number of rows" do
    assert_equal 1, resolve("limit" => 1).size
  end

  test "limit is capped at the safety maximum" do
    assert_equal 3, resolve("limit" => 100000).size # only 3 exist; cap does not raise
  end

  test "removed schema field is not exposed" do
    @collection.update!(fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    row = ActiveCanvas::CollectionSource.new(@collection.reload).resolve.first
    assert row.key?("name")
    refute row.key?("rank")
  end

  test "number sort is numeric not lexical" do
    big = @collection.items.new
    big.assign_fields("name" => "Zed", "rank" => 10, "dept" => "eng")
    big.save!; big.publish!
    ranks = resolve("sort_field" => "rank", "sort_dir" => "asc").map { |r| r["rank"] }
    assert_equal [ 1, 2, 3, 10 ], ranks
  end

  test "media field resolves to a url for every row" do
    coll = ActiveCanvas::Collection.create!(name: "Gallery", slug: "gallery",
      fields: [ { "label" => "Photo", "type" => "media" } ])
    2.times do
      media = ActiveCanvas::Media.new
      media.file.attach(io: StringIO.new("x"), filename: "x.png", content_type: "image/png")
      media.save!
      item = coll.items.new; item.assign_fields("photo" => media.id); item.save!; item.publish!
    end
    rows = ActiveCanvas::CollectionSource.new(coll).resolve
    assert_equal 2, rows.size
    assert(rows.all? { |r| r["photo"].to_s.present? })
  end

  test "text values reach Liquid escaped" do
    publish("<a href=\"https://evil\">login</a>", 9, "eng")
    row = resolve.find { |r| r["rank"] == 9 }
    assert_equal "&lt;a href=&quot;https://evil&quot;&gt;login&lt;/a&gt;", row["name"]
  end

  test "limit of zero, negative or non-numeric falls back to the default" do
    assert_equal 3, resolve("limit" => "0").size
    assert_equal 3, resolve("limit" => "-1").size
    assert_equal 3, resolve("limit" => "abc").size
    assert_equal 3, resolve("limit" => nil).size
    assert_equal 2, resolve("limit" => "2").size
    assert_equal 2, resolve("limit" => 2).size
  end

  test "number sort survives a legacy string value and puts it last both ways" do
    legacy = @collection.items.create!
    # update_columns bypasses coercion on purpose: publish! would turn "abc" into nil
    legacy.update_columns(data: { "name" => "Zed", "rank" => "abc" }, status: "published", published_at: Time.current)
    asc = resolve("sort_field" => "rank", "sort_dir" => "asc").map { |r| r["name"] }
    desc = resolve("sort_field" => "rank", "sort_dir" => "desc").map { |r| r["name"] }
    assert_equal %w[Bob Ada Cy Zed], asc
    assert_equal %w[Cy Ada Bob Zed], desc
  end

  test "nil values sort last in both directions" do
    none = @collection.items.new
    none.assign_fields("name" => "Nil", "dept" => "eng"); none.save!; none.publish!
    asc = resolve("sort_field" => "rank", "sort_dir" => "asc").map { |r| r["name"] }
    desc = resolve("sort_field" => "rank", "sort_dir" => "desc").map { |r| r["name"] }
    assert_equal "Nil", asc.last
    assert_equal "Nil", desc.last
  end

  test "any sort_dir other than asc is descending" do
    assert_equal %w[Cy Ada Bob], resolve("sort_field" => "rank", "sort_dir" => "sideways").map { |r| r["name"] }
    assert_equal %w[Cy Ada Bob], resolve("sort_field" => "rank").map { |r| r["name"] }
  end

  test "boolean fields sort false before true ascending" do
    coll = ActiveCanvas::Collection.create!(name: "Flags", slug: "flags",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "On", "type" => "boolean" } ])
    [ [ "t", true ], [ "f", false ] ].each do |name, on|
      item = coll.items.new; item.assign_fields("name" => name, "on" => on); item.save!; item.publish!
    end
    names = ActiveCanvas::CollectionSource.new(coll).resolve("sort_field" => "on", "sort_dir" => "asc").map { |r| r["name"] }
    assert_equal %w[f t], names
  end

  test "text sort ignores case" do
    publish("zed", 4, "eng")
    publish("Beth", 5, "eng")
    names = resolve("sort_field" => "name", "sort_dir" => "asc").map { |r| r["name"] }
    assert_equal %w[Ada Beth Bob Cy zed], names
  end

  test "ties are broken by id so the order is stable" do
    publish("Ada2", 2, "eng")
    twice = 2.times.map { resolve("sort_field" => "rank", "sort_dir" => "asc").map { |r| r["id"] } }
    assert_equal twice[0], twice[1]
    tied = resolve("sort_field" => "rank", "sort_dir" => "asc").select { |r| r["rank"] == 2 }.map { |r| r["id"] }
    assert_equal tied.sort, tied
  end

  # -- row_for / rows_for (Part 4 "Item row") --------------------------------

  def with_page_options(collection, per_page: 12, title_field: nil, description_field: nil, image_field: nil)
    collection.update!(per_page: per_page, title_field: title_field, description_field: description_field,
      image_field: image_field)
    collection
  end

  test "row_for includes the base fields plus url and seo" do
    with_page_options(@collection, title_field: "name")
    @a.update!(slug: "ada")
    row = ActiveCanvas::CollectionSource.new(@collection).row_for(@a)
    assert_equal @a.id, row["id"]
    assert_equal "ada", row["slug"]
    assert_equal "Ada", row["name"]
    assert_equal "/canvas/team/ada", row["url"]
    assert_equal({ "title" => "Ada", "description" => "", "image_url" => nil }, row["seo"])
  end

  test "row_for seo title falls back from _seo.meta_title to the title field to the slug" do
    with_page_options(@collection, title_field: "name")
    @a.update!(slug: "ada")
    row = ActiveCanvas::CollectionSource.new(@collection).row_for(@a)
    assert_equal "Ada", row["seo"]["title"]

    with_page_options(@collection, title_field: nil)
    row = ActiveCanvas::CollectionSource.new(@collection).row_for(@a.reload)
    assert_equal "ada", row["seo"]["title"]

    @a.update!(data: @a.data.merge("_seo" => { "meta_title" => "Custom Title" }))
    with_page_options(@collection, title_field: "name")
    row = ActiveCanvas::CollectionSource.new(@collection).row_for(@a.reload)
    assert_equal "Custom Title", row["seo"]["title"]
  end

  test "row_for seo description is stripped of rich text and truncated to 160" do
    coll = ActiveCanvas::Collection.create!(name: "Blog", slug: "blog",
      fields: [ { "label" => "Title", "type" => "text" }, { "label" => "Body", "type" => "rich_text" } ])
    with_page_options(coll, description_field: "body")
    long_html = "<p>#{"word " * 40}</p>"
    item = coll.items.new
    item.assign_fields("title" => "Post", "body" => long_html)
    item.save!; item.publish!

    row = ActiveCanvas::CollectionSource.new(coll).row_for(item)
    assert row["seo"]["description"].length <= 160
    refute_includes row["seo"]["description"], "<p>"

    item.update!(data: item.data.merge("_seo" => { "meta_description" => "Explicit description" }))
    row = ActiveCanvas::CollectionSource.new(coll).row_for(item.reload)
    assert_equal "Explicit description", row["seo"]["description"]
  end

  test "row_for seo image_url falls back from _seo.og_image_media_id to the image field" do
    coll = ActiveCanvas::Collection.create!(name: "Gallery2", slug: "gallery2",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Photo", "type" => "media" } ])
    with_page_options(coll, image_field: "photo")
    media = build_saved_media
    other_media = build_saved_media(filename: "og.png")

    item = coll.items.new
    item.assign_fields("name" => "Item", "photo" => media.id)
    item.save!; item.publish!

    # Signed Active Storage URLs embed an expiry, so two calls can differ by a
    # second; compare the file the URL points at instead of the full string.
    row = ActiveCanvas::CollectionSource.new(coll).row_for(item)
    assert_includes row["seo"]["image_url"], "/sample.png"

    item.update!(data: item.data.merge("_seo" => { "og_image_media_id" => other_media.id }))
    row = ActiveCanvas::CollectionSource.new(coll).row_for(item.reload)
    assert_includes row["seo"]["image_url"], "/og.png"
  end

  test "row_for seo values are HTML-escaped" do
    with_page_options(@collection, title_field: "name")
    xss = @collection.items.new
    xss.assign_fields("name" => "<script>1</script>", "rank" => 1, "dept" => "eng")
    xss.save!; xss.publish!

    row = ActiveCanvas::CollectionSource.new(@collection).row_for(xss)
    refute_includes row["seo"]["title"], "<script>"
    assert_includes row["seo"]["title"], "&lt;script&gt;"
  end

  test "row_for(data: :draft) reads the draft snapshot" do
    with_page_options(@collection, title_field: "name")
    draft = @collection.items.new
    draft.assign_fields("name" => "Draft Ada", "rank" => 5, "dept" => "eng")
    draft.save! # not published

    row = ActiveCanvas::CollectionSource.new(@collection).row_for(draft, data: :draft)
    assert_equal "Draft Ada", row["name"]
    assert_equal "Draft Ada", row["seo"]["title"]
  end

  test "rows_for returns the same shape as row_for for each item" do
    with_page_options(@collection, title_field: "name")
    rows = ActiveCanvas::CollectionSource.new(@collection).rows_for([ @a, @b ])
    assert_equal 2, rows.size
    assert_equal %w[Ada Bob], rows.map { |r| r["name"] }
    assert(rows.all? { |r| r["url"].present? && r["seo"].present? })
  end

  test "index_url is engine-mount aware" do
    assert_equal "/canvas/team", ActiveCanvas::CollectionSource.new(@collection).index_url
  end
end
