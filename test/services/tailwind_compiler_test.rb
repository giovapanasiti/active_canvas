require "test_helper"

module ActiveCanvas
  class TailwindCompilerTest < ActiveSupport::TestCase
    setup do
      TailwindCompiler.clear_availability_cache!
    end

    test "available? returns true when tailwindcss-ruby gem is installed" do
      skip "tailwindcss-ruby gem not installed" unless defined?(Tailwindcss::Ruby)
      assert TailwindCompiler.available?
    end

    test "compile_for_page returns empty string for blank content" do
      skip "tailwindcss-ruby gem not installed" unless TailwindCompiler.available?

      page = ActiveCanvas::Page.new(content: "")
      assert_equal "", TailwindCompiler.compile_for_page(page)
    end

    test "compile_for_page compiles Tailwind classes" do
      skip "tailwindcss-ruby gem not installed" unless TailwindCompiler.available?

      page = ActiveCanvas::Page.new(content: '<div class="bg-blue-500 text-white p-4">Test</div>')
      compiled_css = TailwindCompiler.compile_for_page(page)

      assert compiled_css.present?
      assert compiled_css.include?("tailwindcss")
    end
  end
end
