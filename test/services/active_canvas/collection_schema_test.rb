require "test_helper"

class ActiveCanvas::CollectionSchemaTest < ActiveSupport::TestCase
  FIELDS = [
    { "id" => "title",   "type" => "text" },
    { "id" => "body",    "type" => "rich_text" },
    { "id" => "count",   "type" => "number" },
    { "id" => "active",  "type" => "boolean" },
    { "id" => "on",      "type" => "date" },
    { "id" => "photo",   "type" => "media" },
    { "id" => "cat",     "type" => "select", "options" => %w[news blog] }
  ].freeze

  def schema
    ActiveCanvas::CollectionSchema.new(FIELDS)
  end

  test "generate_field_id snakes the label and dedupes" do
    assert_equal "full_name", ActiveCanvas::CollectionSchema.generate_field_id("Full Name!", [])
    assert_equal "name_2", ActiveCanvas::CollectionSchema.generate_field_id("Name", %w[name])
    assert_equal "field", ActiveCanvas::CollectionSchema.generate_field_id("", [])
  end

  test "field_ids lists ids in order" do
    assert_equal %w[title body count active on photo cat], schema.field_ids
  end

  test "coerce_for_storage by type" do
    assert_equal "hi", schema.coerce_for_storage("title", "hi")
    assert_equal 3, schema.coerce_for_storage("count", "3")
    assert_equal 1.5, schema.coerce_for_storage("count", "1.5")
    assert_nil schema.coerce_for_storage("count", "")
    assert_nil schema.coerce_for_storage("count", "abc")
    assert_nil schema.coerce_for_storage("on", "not a date")
    assert_equal true, schema.coerce_for_storage("active", "1")
    assert_equal false, schema.coerce_for_storage("active", "0")
    assert_equal "2026-07-02", schema.coerce_for_storage("on", "July 2, 2026")
    assert_equal "news", schema.coerce_for_storage("cat", "news")
    assert_nil schema.coerce_for_storage("cat", "nope")
    assert_equal 42, schema.coerce_for_storage("photo", "42")
  end

  test "coerce_for_storage sanitizes rich_text" do
    out = schema.coerce_for_storage("body", "<p>ok</p><script>alert(1)</script>")
    assert_includes out, "<p>ok</p>"
    refute_includes out, "<script>"
  end

  test "coerce_for_storage returns nil for unknown field" do
    assert_nil schema.coerce_for_storage("nope", "x")
  end

  test "coerce_for_liquid by type" do
    assert_equal "hi", schema.coerce_for_liquid("title", "hi")
    assert_equal 3, schema.coerce_for_liquid("count", 3)
    assert_equal true, schema.coerce_for_liquid("active", true)
    assert_equal Date.new(2026, 7, 2), schema.coerce_for_liquid("on", "2026-07-02")
    assert schema.coerce_for_liquid("body", "<b>x</b>").html_safe?
  end

  test "coerce_for_liquid media resolves to a url string" do
    media = ActiveCanvas::Media.new
    media.file.attach(io: StringIO.new("x"), filename: "x.png", content_type: "image/png")
    media.save!
    url = schema.coerce_for_liquid("photo", media.id)
    assert_kind_of String, url
    assert url.present?
  end

  test "coerce_for_liquid media returns empty string for missing media" do
    assert_equal "", schema.coerce_for_liquid("photo", 999999)
  end
end
