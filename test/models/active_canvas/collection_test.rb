require "test_helper"

class ActiveCanvas::CollectionTest < ActiveSupport::TestCase
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "valid with name, slug and fields" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team", fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    assert collection.valid?
  end

  test "requires a name" do
    assert_not ActiveCanvas::Collection.new(slug: "team").valid?
  end

  test "a blank slug is derived from the name" do
    collection = ActiveCanvas::Collection.create!(name: "Our Team")
    assert_equal "our-team", collection.slug
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

  test "a field missing its label is invalid" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team",
      fields: [ { "id" => "name", "label" => "", "type" => "text" } ])
    assert_not collection.valid?
  end

  test "a field with an unknown type is invalid" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team",
      fields: [ { "id" => "name", "label" => "Name", "type" => "bogus" } ])
    assert_not collection.valid?
  end

  test "two fields sharing an explicit id are invalid" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team",
      fields: [ { "id" => "dupe", "label" => "One", "type" => "text" },
                { "id" => "dupe", "label" => "Two", "type" => "text" } ])
    assert_not collection.valid?
  end

  test "a well-formed multi-field schema is valid" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" },
                { "id" => "bio", "label" => "Bio", "type" => "rich_text" },
                { "id" => "joined", "label" => "Joined", "type" => "date" } ])
    assert collection.valid?
  end

  test "an empty fields array is valid" do
    assert ActiveCanvas::Collection.new(name: "Team", slug: "team", fields: []).valid?
  end

  test "destroying a collection destroys its items" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team")
    collection.items.create!(status: "draft")
    collection.destroy
    assert_equal 0, ActiveCanvas::CollectionItem.count
  end

  test "a field labelled like a reserved row key gets a suffixed id" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Id", "type" => "text" }, { "label" => "Slug", "type" => "text" }, { "label" => "Published at", "type" => "date" } ])
    assert_equal %w[id_2 slug_2 published_at_2], collection.fields.map { |f| f["id"] }
  end

  test "an explicit reserved field id is invalid" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team",
      fields: [ { "id" => "id", "label" => "Id", "type" => "text" } ])
    assert_not collection.valid?
    assert_includes collection.errors[:fields].join, "reserved"
  end

  test "a field id must be snake_case starting with a letter" do
    [ "Has Space", "Upper", "1st", "with-dash" ].each do |bad|
      collection = ActiveCanvas::Collection.new(name: "Team", slug: "team",
        fields: [ { "id" => bad, "label" => "X", "type" => "text" } ])
      assert_not collection.valid?, "expected #{bad.inspect} to be rejected"
    end
  end

  test "a label starting with a digit gets a letter prefix" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "2nd line", "type" => "text" } ])
    assert_equal %w[f_2nd_line], collection.fields.map { |f| f["id"] }
  end

  test "a dashed label produces a valid id" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "E-mail", "type" => "text" } ])
    assert_equal %w[e_mail], collection.fields.map { |f| f["id"] }
  end

  test "fields that are not an array of hashes are invalid" do
    [ "junk", [ "junk" ], { "a" => 1 } ].each do |bad|
      collection = ActiveCanvas::Collection.new(name: "Team", slug: "team", fields: bad)
      assert_not collection.valid?, "expected #{bad.inspect} to be rejected"
      assert_includes collection.errors[:fields].join, "could not be read"
    end
  end

  test "param_schema describes limit, sort and filter params from the fields" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Dept", "type" => "select", "options" => %w[eng sales] } ])
    schema = collection.param_schema
    assert_equal({ type: :integer, default: 100, range: [ 1, 500 ], allowed: nil }, schema[:limit])
    assert_equal %w[name dept], schema[:sort_field][:allowed]
    assert_equal({ "name" => "Name", "dept" => "Dept" }, schema[:sort_field][:labels])
    assert_equal %w[asc desc], schema[:sort_dir][:allowed]
    assert_equal "desc", schema[:sort_dir][:default]
    assert_equal %w[name dept], schema[:filter_field][:allowed]
    assert_equal({ type: :string, default: nil, range: nil, allowed: nil }, schema[:filter_value])
  end

  test "item_name comes from the slug" do
    assert_equal "member", ActiveCanvas::Collection.new(name: "Members", slug: "members").item_name
    assert_equal "item", ActiveCanvas::Collection.new(name: "Team", slug: "team").item_name
  end

  test "fields_json= parses the field builder payload" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team")
    collection.fields_json = [ { "label" => "Name", "type" => "text" } ].to_json
    assert collection.valid?
    assert_equal %w[name], collection.fields.map { |f| f["id"] }
  end

  test "fields_json= with a blank payload clears the fields" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
    collection.fields_json = ""
    assert_equal [], collection.fields
  end

  test "fields_json= with unreadable payloads adds a validation error instead of raising" do
    [ "{not json", "42", '{"a":1}', [ "1" ] ].each do |bad|
      collection = ActiveCanvas::Collection.new(name: "Team", slug: "team")
      collection.fields_json = bad
      assert_not collection.valid?, "expected #{bad.inspect} to be invalid"
      assert_includes collection.errors[:fields].join, "could not be read"
    end
  end

  test "fields_json serializes the fields for the builder" do
    collection = ActiveCanvas::Collection.new(name: "Team", slug: "team", fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    assert_equal [ { "id" => "name", "label" => "Name", "type" => "text" } ], JSON.parse(collection.fields_json)
  end
end
