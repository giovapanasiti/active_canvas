require "test_helper"

class ActiveCanvas::TailwindRecompileTest < ActiveSupport::TestCase
  test "raises Unavailable when the framework is not tailwind" do
    ActiveCanvas::Setting.css_framework = "bootstrap5"

    error = assert_raises(ActiveCanvas::TailwindRecompile::Unavailable) { ActiveCanvas::TailwindRecompile.call }

    if ActiveCanvas::TailwindCompiler.available?
      assert_equal "Tailwind is not the selected CSS framework.", error.message
    else
      # Without the gem, TailwindRecompile can't even get to the framework
      # check; it still raises Unavailable, just with the gem's message.
      assert_equal "tailwindcss-ruby gem is not installed.", error.message
    end
  end

  test "enqueues a compile job for every page with content" do
    skip "tailwindcss-ruby gem not installed" unless ActiveCanvas::TailwindCompiler.available?

    page_type = ActiveCanvas::PageType.create!(name: "Test")
    ActiveCanvas::Page.create!(title: "P", page_type: page_type, content: "<p>hi</p>")
    ActiveCanvas::Page.create!(title: "Empty", page_type: page_type, content: "")

    ActiveCanvas::Setting.css_framework = "tailwind"

    result = ActiveCanvas::TailwindRecompile.call
    assert_equal 1, result[:enqueued]
  end
end
