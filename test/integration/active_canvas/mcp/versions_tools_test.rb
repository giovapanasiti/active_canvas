require "test_helper"

class ActiveCanvas::Mcp::VersionsToolsTest < ActionDispatch::IntegrationTest
  setup do
    @rwp = mcp_token(%w[read write publish])
    @page_type = ActiveCanvas::PageType.create!(name: "Versioned")
    @page = ActiveCanvas::Page.create!(title: "V", page_type: @page_type, content: "<p>v1</p>")
    @page.update!(content: "<p>v2</p>")
    @page.update!(content: "<p>v3</p>")
  end

  test "list_page_versions returns summaries newest first" do
    listed, err = mcp_call(@rwp, "list_page_versions", { page_id: @page.id })
    assert_nil err
    numbers = listed["items"].map { |v| v["version_number"] }
    assert_equal numbers.sort.reverse, numbers
    assert listed["items"].first.key?("changed_by")
    assert listed["items"].first.key?("content_size_after")
    refute listed["items"].first.key?("content_after")
  end

  test "get_page_version returns full before/after content and diff" do
    version = @page.versions.oldest_first.first
    got, err = mcp_call(@rwp, "get_page_version", { page_id: @page.id, version_number: version.version_number })
    assert_nil err
    assert_equal version.content_before, got["content_before"]
    assert_equal version.content_after, got["content_after"]
    assert got.key?("content_diff")
  end

  test "restore_page_version resets content to that version's saved state and creates a new version" do
    target_version = @page.versions.oldest_first.first # before "<p>v1</p>" after "<p>v2</p>"
    version_count_before = @page.versions.count

    result, err = mcp_call(@rwp, "restore_page_version", { page_id: @page.id, version_number: target_version.version_number })
    assert_nil err

    @page.reload
    assert_equal "<p>v2</p>", @page.content
    assert_equal version_count_before + 1, @page.versions.count
    assert_equal @page.current_version_number, result["version_number"]
    assert_equal @page.id, result["page"]["id"]
  end

  test "restoring a published page requires the publish scope and leaves the DB unchanged" do
    @page.update!(published: true)
    rw = mcp_token(%w[read write])
    version = @page.versions.oldest_first.first
    content_before = @page.content
    version_count_before = @page.versions.count

    _, err = mcp_call(rw, "restore_page_version", { page_id: @page.id, version_number: version.version_number })
    assert_match(/requires the 'publish' scope/, err)

    @page.reload
    assert_equal content_before, @page.content
    assert_equal version_count_before, @page.versions.count
  end

  test "a read write token can restore an unpublished page" do
    rw = mcp_token(%w[read write])
    version = @page.versions.oldest_first.first
    _, err = mcp_call(rw, "restore_page_version", { page_id: @page.id, version_number: version.version_number })
    assert_nil err
  end

  test "restore_page_version succeeds for a template version referencing the implicit item context" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    template = collection.template_pages.find_by!(collection_role: "show")
    # Without the implicit context applied to the strict preview render, restoring this would
    # fail with an "undefined variable" error even though the content is valid on a show template.
    version = template.versions.create!(
      content_before: template.content, content_after: "<h1>{{ item.name }}</h1>",
      css_before: "", css_after: "", bindings_before: {}, bindings_after: {}
    )

    _, err = mcp_call(@rwp, "restore_page_version", { page_id: template.id, version_number: version.version_number })
    assert_nil err
    assert_equal "<h1>{{ item.name }}</h1>", template.reload.content
  end

  test "restoring a version with invalid Liquid on a template_enabled page returns a line error and leaves the page unchanged" do
    page = ActiveCanvas::Page.create!(title: "Templated", page_type: @page_type, content: "<p>ok</p>", template_enabled: true)
    bad_version = page.versions.create!(
      content_before: page.content, content_after: "{% if %}",
      css_before: "", css_after: "", bindings_before: {}, bindings_after: {}
    )
    content_before = page.content
    version_count_before = page.versions.count

    _, err = mcp_call(@rwp, "restore_page_version", { page_id: page.id, version_number: bad_version.version_number })
    assert_match(/line/, err)

    page.reload
    assert_equal content_before, page.content
    assert_equal version_count_before, page.versions.count
  end
end
