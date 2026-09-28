require "test_helper"

class ActiveCanvas::Mcp::RegistryTest < ActionDispatch::IntegrationTest
  # The full tool name list from the spec's tool tables (docs/superpowers/specs/2026-09-27-mcp-server-design.md),
  # adjusted for the rulings recorded in .superpowers/sdd/2026-09-27-mcp-server/progress.md:
  # page types are list/create/update/delete (no separate "filename" concern), and generate_image
  # takes no `filename` argument (the Media it creates names itself).
  EXPECTED_TOOL_NAMES = %w[
    list_pages get_page create_page update_page update_page_content delete_page set_page_published
    list_page_versions get_page_version restore_page_version
    list_data_sources validate_template preview_template_values sample_binding_data render_page_preview
    list_page_types create_page_type update_page_type delete_page_type
    list_partials get_partial update_partial
    list_media get_media upload_media delete_media
    list_form_submissions get_form_submission delete_form_submission export_form_submissions_csv
    list_collections get_collection create_collection update_collection delete_collection
    list_collection_items get_collection_item create_collection_item update_collection_item
    delete_collection_item publish_collection_item unpublish_collection_item get_collection_item_history
    get_settings update_site_settings recompile_tailwind
    get_ai_status list_ai_models update_ai_settings sync_ai_models set_ai_models_active
    create_ai_model delete_ai_model generate_image
  ].freeze

  setup { ActiveCanvas::Mcp::Registry.load_tools! }

  test "every tool has a non-empty description, a valid required_scope and a unique tool_name" do
    tools = ActiveCanvas::Mcp::BaseTool.descendants
    assert tools.any?, "expected at least one registered tool"

    names = tools.map(&:name_value)
    assert_equal names.uniq.length, names.length, "duplicate tool_name(s): #{names.tally.select { |_, n| n > 1 }.keys}"

    tools.each do |tool|
      assert tool.description.present?, "#{tool.name_value}: description must not be blank"
      assert_includes %i[read write publish], tool.required_scope, "#{tool.name_value}: required_scope must be one of read/write/publish"
    end
  end

  test "every tool named in the spec's tool tables is registered" do
    actual_names = ActiveCanvas::Mcp::BaseTool.descendants.map(&:name_value)
    assert_equal EXPECTED_TOOL_NAMES.sort, actual_names.sort
  end

  test "a read-only token's tools/list contains only read-scoped tools" do
    read_only_names = ActiveCanvas::Mcp::BaseTool.descendants.select { |t| t.required_scope == :read }.map(&:name_value)
    listed = mcp_tool_names(mcp_token(%w[read]))

    assert_equal read_only_names.sort, listed.sort
  end

  test "a full-scope token's tools/list contains every registered tool" do
    listed = mcp_tool_names(mcp_token(%w[read write publish]))

    assert_equal ActiveCanvas::Mcp::BaseTool.descendants.map(&:name_value).sort, listed.sort
  end

  test "load_tools! skips eager_load_dir when config.eager_load is already true" do
    called = false
    stub_method(Rails.autoloaders.main, :eager_load_dir, ->(*) { called = true }) do
      stub_method(Rails.application.config, :eager_load, true) do
        ActiveCanvas::Mcp::Registry.load_tools!
      end
    end

    refute called, "expected load_tools! not to re-run eager_load_dir when the app is already eager-loaded"
  end

  test "load_tools! still eager loads the tools dir when config.eager_load is false" do
    called = false
    stub_method(Rails.autoloaders.main, :eager_load_dir, ->(*) { called = true }) do
      stub_method(Rails.application.config, :eager_load, false) do
        ActiveCanvas::Mcp::Registry.load_tools!
      end
    end

    assert called
  end
end
