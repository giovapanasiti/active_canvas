require "test_helper"

class ActiveCanvas::CollectionItemSlugPublishTest < ActiveSupport::TestCase
  def plain_collection
    ActiveCanvas::Collection.create!(name: "Notes", slug: "notes",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
  end

  def pages_collection
    ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
  end

  test "a blank slug is stored as nil, so two blank-slug items can coexist" do
    collection = plain_collection
    first = collection.items.create!(slug: "")
    second = collection.items.create!(slug: "  ")

    assert_nil first.reload.slug
    assert_nil second.reload.slug
  end

  test "publish returns false with errors instead of raising when the record is invalid" do
    collection = pages_collection
    item = collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.update_column(:slug, nil)

    result = nil
    assert_nothing_raised { result = item.publish }
    assert_equal false, result
    assert item.errors[:slug].any?, "expected a slug error, got #{item.errors.full_messages.inspect}"
    assert_equal "draft", item.reload.status
    assert_equal 0, item.versions.count
  end

  test "pending_changes? notices a draft-only _seo change" do
    collection = pages_collection
    item = collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!
    refute item.pending_changes?

    item.assign_fields("_seo" => { "meta_title" => "New title" })
    item.save!

    assert item.pending_changes?
  end

  test "enabling has_pages backfills slugs on existing slug-less items" do
    collection = plain_collection
    items = %w[Ada Grace].map do |name|
      item = collection.items.new
      item.assign_fields("name" => name)
      item.save!
      item.publish!
      item
    end
    assert items.all? { |item| item.reload.slug.nil? }

    collection.update!(has_pages: true, title_field: "name")

    slugs = items.map { |item| item.reload.slug }
    assert_equal %w[ada grace], slugs.sort
  end

  test "the show template's live context doesn't add an unsaved item to the collection's items" do
    collection = pages_collection
    show = collection.template_pages.find_by!(collection_role: "show")
    show.collection.items.load

    context = ActiveCanvas::TemplateEditorContext.live(show)

    assert context.key?("item")
    assert_empty show.collection.items.target
  end
end
