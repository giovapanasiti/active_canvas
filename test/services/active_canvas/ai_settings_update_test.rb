require "test_helper"

class ActiveCanvas::AiSettingsUpdateTest < ActiveSupport::TestCase
  test "a masked key is not overwritten" do
    ActiveCanvas::Setting.set("ai_openai_api_key", "sk-real-secret")

    result = ActiveCanvas::AiSettingsUpdate.call({ ai_openai_api_key: "****abcd" })

    assert result
    assert_equal "sk-real-secret", ActiveCanvas::Setting.get("ai_openai_api_key")
  end

  test "a blank key is not overwritten" do
    ActiveCanvas::Setting.set("ai_openai_api_key", "sk-real-secret")

    ActiveCanvas::AiSettingsUpdate.call({ ai_openai_api_key: "" })

    assert_equal "sk-real-secret", ActiveCanvas::Setting.get("ai_openai_api_key")
  end

  test "a real key value is stored" do
    ActiveCanvas::AiSettingsUpdate.call({ ai_anthropic_api_key: "sk-ant-new" })

    assert_equal "sk-ant-new", ActiveCanvas::Setting.get("ai_anthropic_api_key")
  end

  test "toggles persist and accept '1'/'0' strings" do
    ActiveCanvas::AiSettingsUpdate.call({ ai_text_enabled: "0", ai_image_enabled: "1" })

    refute ActiveCanvas::Setting.ai_text_enabled?
    assert ActiveCanvas::Setting.ai_image_enabled?
  end

  test "toggles accept real booleans and 'true'/'false' strings" do
    ActiveCanvas::AiSettingsUpdate.call({ ai_text_enabled: false, ai_screenshot_enabled: "true" })

    refute ActiveCanvas::Setting.ai_text_enabled?
    assert ActiveCanvas::Setting.ai_screenshot_enabled?
  end

  test "nil or blank leaves the toggle disabled, not enabled" do
    ActiveCanvas::AiSettingsUpdate.call({ ai_text_enabled: nil })
    refute ActiveCanvas::Setting.ai_text_enabled?

    ActiveCanvas::Setting.ai_image_enabled = true
    ActiveCanvas::AiSettingsUpdate.call({ ai_image_enabled: "" })
    refute ActiveCanvas::Setting.ai_image_enabled?
  end

  test "omitted keys are left untouched (partial update)" do
    ActiveCanvas::Setting.ai_connection_mode = "direct"

    ActiveCanvas::AiSettingsUpdate.call({ ai_text_enabled: "1" })

    assert_equal "direct", ActiveCanvas::Setting.ai_connection_mode
  end
end
