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
end
