require "test_helper"

class ActiveCanvas::Mcp::AiToolsTest < ActionDispatch::IntegrationTest
  setup { @rw = mcp_token(%w[read write publish]) }

  test "get_ai_status returns the same shape as AiConfiguration.status_payload" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-configured"

    status, err = mcp_call(@rw, "get_ai_status")
    assert_nil err
    assert_equal ActiveCanvas::AiConfiguration.status_payload.as_json, status
  end

  test "list_ai_models paginates, orders by provider/model_id and excludes inactive by default" do
    ActiveCanvas::AiModel.create!(model_id: "z-model", provider: "openai", model_type: "chat", active: true)
    ActiveCanvas::AiModel.create!(model_id: "a-model", provider: "openai", model_type: "chat", active: true)
    inactive = ActiveCanvas::AiModel.create!(model_id: "old-model", provider: "openai", model_type: "chat", active: false)

    listed, err = mcp_call(@rw, "list_ai_models")
    assert_nil err
    ids = listed["items"].map { |i| i["id"] }
    assert_equal %w[a-model z-model], ids
    assert listed["items"].all? { |i| i.key?("active") }

    with_inactive, err = mcp_call(@rw, "list_ai_models", { include_inactive: true })
    assert_nil err
    assert_includes with_inactive["items"].map { |i| i["id"] }, inactive.model_id
  end

  test "update_ai_settings does not overwrite an api key when given a masked value" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-real-secret"

    _, err = mcp_call(@rw, "update_ai_settings", { openai_api_key: "****abcd" })
    assert_nil err
    ActiveCanvas::Current.reset
    assert_equal "sk-real-secret", ActiveCanvas::Setting.ai_openai_api_key
  end

  test "update_ai_settings applies model defaults and toggles, never returning a raw key" do
    ActiveCanvas::Setting.ai_anthropic_api_key = "sk-ant-real-secret"

    body = mcp_rpc(@rw, "tools/call", {
      name: "update_ai_settings",
      arguments: { default_text_model: "gpt-4o", text_enabled: false, anthropic_api_key: "sk-ant-new-secret" }
    })
    raw_text = body["result"]["content"].first["text"]
    ActiveCanvas::Current.reset

    assert_equal "gpt-4o", ActiveCanvas::Setting.ai_default_text_model
    refute ActiveCanvas::Setting.ai_text_enabled?
    assert_equal "sk-ant-new-secret", ActiveCanvas::Setting.ai_anthropic_api_key
    assert_not_includes raw_text, "sk-ant-new-secret"
  end

  test "sync_ai_models errors when AI is not configured" do
    _, err = mcp_call(@rw, "sync_ai_models")
    refute_nil err
    assert_match(/not configured/i, err)
  end

  test "sync_ai_models refreshes models (network stubbed)" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-configured"

    result = nil
    err = nil
    stub_method(ActiveCanvas::AiModels, :refresh!, 3) do
      result, err = mcp_call(@rw, "sync_ai_models")
    end

    assert_nil err
    assert_equal 3, result["synced"]
  end

  test "sync_ai_models turns a provider exception into a generic tool error, logging the real one" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-configured"

    _, err = nil
    log = capture_log do
      stub_method(ActiveCanvas::AiModels, :refresh!, ->(*) { raise "provider exploded" }) do
        _, err = mcp_call(@rw, "sync_ai_models")
      end
    end

    assert_equal "Model sync failed (RuntimeError)", err
    refute_match(/provider exploded/, err)
    assert_match(/provider exploded/, log)
  end

  test "set_ai_models_active toggles several models" do
    m1 = ActiveCanvas::AiModel.create!(model_id: "m1", provider: "openai", active: false)
    m2 = ActiveCanvas::AiModel.create!(model_id: "m2", provider: "openai", active: false)

    result, err = mcp_call(@rw, "set_ai_models_active", { model_ids: [ m1.model_id, m2.model_id ], active: true })
    assert_nil err
    assert_equal 2, result["updated"]
    assert m1.reload.active?
    assert m2.reload.active?
  end

  test "set_ai_models_active errors listing unknown model ids" do
    known = ActiveCanvas::AiModel.create!(model_id: "known", provider: "openai", active: true)

    _, err = mcp_call(@rw, "set_ai_models_active", { model_ids: [ known.model_id, "ghost-1", "ghost-2" ], active: false })
    refute_nil err
    assert_match(/ghost-1/, err)
    assert_match(/ghost-2/, err)
  end

  test "create_ai_model and delete_ai_model work" do
    created, err = mcp_call(@rw, "create_ai_model", {
      model_id: "custom-model-1",
      provider: "openai",
      model_type: "chat",
      name: "Custom Model",
      input_modalities: [ "text" ],
      output_modalities: [ "text" ],
      supports_functions: true,
      active: true
    })
    assert_nil err
    assert ActiveCanvas::AiModel.exists?(model_id: "custom-model-1")
    assert_equal "custom-model-1", created["id"]
    assert_equal true, created["active"]

    deleted, err = mcp_call(@rw, "delete_ai_model", { model_id: "custom-model-1" })
    assert_nil err
    assert_equal true, deleted["deleted"]
    assert_not ActiveCanvas::AiModel.exists?(model_id: "custom-model-1")
  end

  test "create_ai_model rejects a duplicate model_id" do
    ActiveCanvas::AiModel.create!(model_id: "dup", provider: "openai")

    _, err = mcp_call(@rw, "create_ai_model", { model_id: "dup", provider: "openai" })
    refute_nil err
    assert_match(/validation failed/i, err)
  end

  test "delete_ai_model errors for an unknown model_id" do
    _, err = mcp_call(@rw, "delete_ai_model", { model_id: "does-not-exist" })
    refute_nil err
    assert_match(/not found/i, err)
  end

  test "generate_image returns an error when image generation is disabled" do
    ActiveCanvas::Setting.ai_image_enabled = false
    ActiveCanvas::Setting.ai_openai_api_key = "sk-configured"

    _, err = mcp_call(@rw, "generate_image", { prompt: "a red circle" })
    refute_nil err
    assert_equal "Image generation is disabled or AI is not configured.", err
  end

  test "generate_image errors when AI is not configured at all" do
    _, err = mcp_call(@rw, "generate_image", { prompt: "a red circle" })
    refute_nil err
    assert_equal "Image generation is disabled or AI is not configured.", err
  end

  test "generate_image succeeds with AiService.generate_image stubbed" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-configured"
    ActiveCanvas::Setting.ai_image_enabled = true
    media = build_saved_media(filename: "generated.png")

    result = nil
    err = nil
    stub_method(ActiveCanvas::AiService, :generate_image, ->(**) { media }) do
      result, err = mcp_call(@rw, "generate_image", { prompt: "a red circle" })
    end

    assert_nil err
    assert_equal media.id, result["media"]["id"]
  end

  test "generate_image turns a provider exception into a generic tool error, logging the real one" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-configured"
    ActiveCanvas::Setting.ai_image_enabled = true

    _, err = nil
    log = capture_log do
      stub_method(ActiveCanvas::AiService, :generate_image, ->(**) { raise "upstream 500: account xyz over quota" }) do
        _, err = mcp_call(@rw, "generate_image", { prompt: "a red circle" })
      end
    end

    assert_equal "Image generation failed (RuntimeError)", err
    refute_match(/account xyz/, err)
    assert_match(/account xyz/, log)
  end

  test "generate_image enforces the ai rate limit, keyed by token" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-configured"
    ActiveCanvas::Setting.ai_image_enabled = true
    media = build_saved_media(filename: "generated.png")

    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    begin
      with_config(ai_rate_limit_per_minute: 1) do
        stub_method(ActiveCanvas::AiService, :generate_image, ->(**) { media }) do
          _, first_err = mcp_call(@rw, "generate_image", { prompt: "one" })
          assert_nil first_err

          _, second_err = mcp_call(@rw, "generate_image", { prompt: "two" })
          assert_equal "AI rate limit exceeded", second_err
        end
      end
    ensure
      Rails.cache = previous_cache
    end
  end

  test "ai mutation tools require write/publish and are not listed for a plain read+write token (no publish)" do
    rw_no_publish = mcp_token(%w[read write])
    names = mcp_tool_names(rw_no_publish)

    assert_not_includes names, "update_ai_settings"
    assert_not_includes names, "sync_ai_models"
    assert_not_includes names, "set_ai_models_active"
    assert_not_includes names, "create_ai_model"
    assert_not_includes names, "delete_ai_model"

    assert_includes names, "get_ai_status"
    assert_includes names, "list_ai_models"
    assert_includes names, "generate_image"
  end
end
