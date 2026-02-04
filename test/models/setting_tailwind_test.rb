require "test_helper"

module ActiveCanvas
  class SettingTailwindTest < ActiveSupport::TestCase
    setup do
      TailwindCompiler.clear_availability_cache!
    end

    test "tailwind_config returns default config when not set" do
      config = Setting.tailwind_config

      assert_kind_of Hash, config
      assert config.key?(:theme)
      assert config[:theme].key?(:extend)
    end

    test "tailwind_config= accepts hash" do
      custom_config = { theme: { extend: { colors: { brand: "#ff0000" } } } }
      Setting.tailwind_config = custom_config

      stored_config = Setting.tailwind_config
      assert_equal "#ff0000", stored_config[:theme][:extend][:colors][:brand]
    end

    test "tailwind_config= accepts json string" do
      custom_config = '{"theme":{"extend":{"colors":{"test":"#00ff00"}}}}'
      Setting.tailwind_config = custom_config

      stored_config = Setting.tailwind_config
      assert_equal "#00ff00", stored_config[:theme][:extend][:colors][:test]
    end

    test "tailwind_config_js returns valid json" do
      js = Setting.tailwind_config_js

      assert_kind_of String, js
      parsed = JSON.parse(js)
      assert_kind_of Hash, parsed
    end

    test "tailwind_compiled_mode? returns true when tailwind is selected and gem is available" do
      skip "tailwindcss-ruby gem not installed" unless TailwindCompiler.available?
      Setting.css_framework = "tailwind"

      assert Setting.tailwind_compiled_mode?
    end

    test "tailwind_compiled_mode? returns false when tailwind is not selected" do
      Setting.css_framework = "bootstrap5"

      refute Setting.tailwind_compiled_mode?
    end
  end
end
