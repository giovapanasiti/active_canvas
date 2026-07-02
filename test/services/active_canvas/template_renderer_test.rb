require "test_helper"

class ActiveCanvas::TemplateRendererTest < ActiveSupport::TestCase
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "short-circuits when template_enabled is false" do
    page = ActiveCanvas::Page.create!(
      title: "Static", page_type: @page_type,
      content: "<h1>{{ should_not_render }}</h1>", template_enabled: false
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public)
    assert_equal "<h1>{{ should_not_render }}</h1>", renderer.render
  end

  test "short-circuit returns content byte-for-byte" do
    page = ActiveCanvas::Page.create!(
      title: "Static", page_type: @page_type,
      content: "  weird  whitespace  ", template_enabled: false
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public)
    assert_equal "  weird  whitespace  ", renderer.render
  end

  test "renders literal binding" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!",
      template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public)
    assert_includes renderer.render, "Hello World!"
  end

  test "enforces render_score_limit" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% for i in (1..10000) %}x{% endfor %}",
      template_enabled: true
    )
    # Tighten the limit so we hit it quickly.
    original = ActiveCanvas.config.template_render_score_limit
    ActiveCanvas.config.template_render_score_limit = 100
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :preview)
    err = assert_raises(ActiveCanvas::DataSources::TemplateRenderError) { renderer.render }
    assert err.original.is_a?(Liquid::MemoryError)
  ensure
    ActiveCanvas.config.template_render_score_limit = original
  end

  test "enforces render_length_limit" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% for i in (1..10000) %}xxxxxxxxxx{% endfor %}",
      template_enabled: true
    )
    original = ActiveCanvas.config.template_render_length_limit
    ActiveCanvas.config.template_render_length_limit = 50
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :preview)
    err = assert_raises(ActiveCanvas::DataSources::TemplateRenderError) { renderer.render }
    assert err.original.is_a?(Liquid::MemoryError)
  ensure
    ActiveCanvas.config.template_render_length_limit = original
  end

  test "sanitizes output AFTER rendering (script injected via data is stripped)" do
    ActiveCanvas.config.sanitize_content = true  # ensure sanitizer is active
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Comment: {{ user_comment }}",
      template_enabled: true,
      bindings: { "user_comment" => { "source" => "_literal", "value" => "<script>alert(1)</script>" } }
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public)
    output = renderer.render
    refute_includes output, "<script>"
  ensure
    ActiveCanvas.config.sanitize_content = false
  end

  test "renders a query data source via auto_drop" do
    ActiveCanvas::DataSources.register(:posts) do
      param :limit, type: :integer, default: 2
      fetch do |limit:|
        (1..limit).map { |i| Struct.new(:id, :title).new(i, "Post#{i}") }
      end
      auto_drop attributes: %i[id title]
    end

    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% for p in posts %}{{ p.title }}|{% endfor %}",
      template_enabled: true,
      bindings: { "posts" => { "source" => "posts", "params" => { "limit" => 3 } } }
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public)
    assert_includes renderer.render, "Post1|Post2|Post3|"
  end

  test "preview mode raises on undefined variable" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{{ undefined_var }}",
      template_enabled: true
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :preview)
    err = assert_raises(ActiveCanvas::DataSources::TemplateRenderError) { renderer.render }
    assert_match(/undefined/i, err.message)
  end

  test "public mode soft-fails on undefined variable" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!",
      template_enabled: true
    )
    original_logger = Rails.logger
    log = StringIO.new
    Rails.logger = Logger.new(log)
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public)
    output = renderer.render
    assert_includes output, "<!-- dynamic block unavailable -->"
    refute_includes output, "{{"
    assert_match(/dynamic.*unavailable|undefined/i, log.string)
  ensure
    Rails.logger = original_logger
  end

  test "preview mode raises on syntax error" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% for x in %}",
      template_enabled: true
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :preview)
    assert_raises(ActiveCanvas::DataSources::TemplateRenderError) { renderer.render }
  end

  test "preview mode wraps output in chip markers" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    assert_match(/data-ac-var="name"/, output)
    assert_match(/World/, output)
  end

  test "decodes HTML entities inside Liquid tags (WYSIWYG editor encoding)" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% if n &gt; 0 %}positive{% else %}zero{% endif %}",
      template_enabled: true,
      bindings: { "n" => { "source" => "_literal", "value" => 5 } }
    )
    assert_includes ActiveCanvas::TemplateRenderer.new(page, mode: :public).render, "positive"
  end

  test "decodes &amp; &lt; &quot; inside output tags" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: %({{ name | append: &quot;!&quot; }}),
      template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "hi" } }
    )
    assert_includes ActiveCanvas::TemplateRenderer.new(page, mode: :public).render, "hi!"
  end

  test "public mode does NOT include chip markers" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    refute_match(/data-ac-var/, output)
    assert_match(/Hello World/, output)
  end

  test "public render heals var chip markup saved back from the editor" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
    # Simulate the editor round-trip: the preview (chip markup) gets saved as content.
    corrupted = ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    page.update!(content: corrupted)

    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    assert_includes output, "Hello World!"
    refute_includes output, "data-ac-"
  end

  test "public render heals block chip markup saved back from the editor" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% for item in items %}<p>{{ item }}</p>{% endfor %}",
      template_enabled: true,
      bindings: { "items" => { "source" => "_literal", "value" => %w[alpha beta] } }
    )
    corrupted = ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    page.update!(content: corrupted)

    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    assert_includes output, "<p>alpha</p>"
    assert_includes output, "<p>beta</p>"
    refute_includes output, "data-ac-"
  end

  test "preview render round-trips its own chip output" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
    corrupted = ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    page.update!(content: corrupted)

    output = ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    assert_includes output, "World"
    assert_match(/data-ac-var/, output) # re-injected markers, not doubled-up corruption
  end
end
