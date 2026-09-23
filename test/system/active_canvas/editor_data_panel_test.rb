# Opt in with:  AC_SYSTEM=1 bin/rails test test/system/active_canvas/editor_data_panel_test.rb
# Requires Chrome. Without AC_SYSTEM every case skips so CI stays green.

require "application_system_test_case"

class ActiveCanvas::EditorDataPanelTest < ApplicationSystemTestCase
  SOURCE = <<~HTML.strip
    <p>Hello {{ name }}</p>
    <a href="{{ url }}">link</a>
    <table><tbody><tr data-ac-for="r in rows"><td>{{ r }}</td></tr></tbody></table>
  HTML

  setup do
    skip "set AC_SYSTEM=1 to run system specs (requires Chrome)" unless ENV["AC_SYSTEM"]
    ActiveCanvas::DataSources.reset_for_testing!

    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(
      title: "Sys", page_type: @page_type, content: SOURCE, template_enabled: true,
      bindings: {
        "name" => { "source" => "_literal", "value" => "World" },
        "url"  => { "source" => "_literal", "value" => "/x" },
        "rows" => { "source" => "_literal", "value" => %w[a b] }
      }
    )
  end

  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "chips decorate {{ }} in the canvas and the loop row is badged" do
    visit "/canvas/admin/pages/#{@page.id}/editor"
    within_frame(find("iframe.gjs-frame")) do
      assert_selector "span[data-ac-var][data-ac-source='{{ name }}']"
      assert_selector "tr[data-ac-for='r in rows'] td span[data-ac-var][data-ac-source='{{ r }}']"
    end
  end

  test "saving keeps every Liquid construct in the source and no chip markup" do
    visit "/canvas/admin/pages/#{@page.id}/editor"
    within_frame(find("iframe.gjs-frame")) { assert_selector "span[data-ac-var][data-ac-source='{{ name }}']" }

    find("#btn-save").click
    assert_text "Page saved successfully", wait: 10

    content = @page.reload.content
    assert_includes content, "{{ name }}"
    assert_includes content, %(href="{{ url }}")
    assert_match(%r{<tr[^>]*data-ac-for="r in rows"[^>]*>\s*<td>\{\{ r \}\}</td>}, content)
    refute_includes content, "data-ac-var"
    assert_nil @page.content_components
  end

  test "adding a binding in the Data panel is saved with the page" do
    visit "/canvas/admin/pages/#{@page.id}/editor"
    find("#btn-toggle-left").click
    click_button "Data"
    find("#ac-add-binding-btn").click
    within("#ac-binding-form") do
      fill_in "name", with: "title"
      find("select[name='source']").select("Literal")
      fill_in "param_value", with: "Hi there"
      click_button "Save binding"
    end
    find("#btn-save").click
    assert_text "Page saved successfully", wait: 10
    assert_equal "Hi there", @page.reload.bindings.dig("title", "value")
  end

  test "a template error shows a banner with the line" do
    visit "/canvas/admin/pages/#{@page.id}/editor"
    find("#btn-toggle-left").click
    click_button "Data"
    find(".data-panel-row", text: "name").hover
    find("[data-remove='name']").click
    assert_selector "#ac-error-banner", text: /undefined variable.*name.*line 1/i
  end


  test "live data shows values in the chips and saving still stores the source" do
    visit "/canvas/admin/pages/#{@page.id}/editor"
    within_frame(find("iframe.gjs-frame")) do
      assert_selector "span[data-ac-var]", text: "World", wait: 10
      assert_selector "tr[data-ac-for='r in rows'] span[data-ac-var]", text: "a"
    end

    find("#btn-save").click
    assert_text "Page saved successfully", wait: 10
    content = @page.reload.content
    assert_includes content, "{{ name }}"
    refute_includes content, "World"
    refute_match(/data-ac-(var|source|id)/, content)

    find("#btn-live-data").click
    within_frame(find("iframe.gjs-frame")) { assert_selector "span[data-ac-var]", text: "{{ name }}" }
  end
end
