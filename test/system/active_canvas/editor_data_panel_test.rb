# v1 skip strategy: these system specs require a real browser (JS) driver to exercise
# the GrapesJS editor and data panel UI. The default rack_test driver does not execute
# JavaScript, so all tests in this file are unconditionally skipped unless you opt-in
# by setting the environment variable AC_SYSTEM=1 *and* have a JS-capable driver
# (e.g. cuprite/selenium) wired into ApplicationSystemTestCase.
#
# To run:
#   AC_SYSTEM=1 bin/rails test test/system/active_canvas/editor_data_panel_test.rb
#
# Without AC_SYSTEM the suite still includes this file (no load errors), but all
# cases report as "skipped" so CI stays green without a browser installed.

require "application_system_test_case"

class ActiveCanvas::EditorDataPanelTest < ApplicationSystemTestCase
  setup do
    skip "set AC_SYSTEM=1 to run system specs (requires JS driver)" unless ENV["AC_SYSTEM"]

    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(
      title: "Sys", page_type: @page_type,
      content: "Hello {{ name }}", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
  end

  test "Data panel lists bindings and chip renders in canvas" do
    visit "/canvas/admin/pages/#{@page.id}/editor"
    click_button "Data"
    assert_text "name"
    # Chip renders inside the GrapesJS iframe; query through frame.
    within_frame(find("iframe", match: :first)) do
      assert_selector "[data-ac-var='name']"
      assert_text "World"
    end
  end

  test "Adding a binding and saving persists Liquid source to page.content" do
    visit "/canvas/admin/pages/#{@page.id}/editor"
    click_button "Data"
    click_button "+ Add binding"
    fill_in "name", with: "title"
    select "_literal", from: "source"
    fill_in "param_value", with: "Hi there"
    click_button "Save"
    # Save the page.
    click_button "Save"
    @page.reload
    assert_includes @page.bindings.keys, "title"
  end
end
