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
    original_sanitize = ActiveCanvas.config.sanitize_content
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
    ActiveCanvas.config.sanitize_content = original_sanitize
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

  test "public mode renders an undefined variable as empty and keeps the page" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "<h1>Hello {{ name }}!</h1>",
      template_enabled: true
    )
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    assert_equal "<h1>Hello !</h1>", output
  end

  test "public mode renders a removed nested field as empty" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% for m in team %}<li>{{ m.name }}|{{ m.rank }}</li>{% endfor %}",
      template_enabled: true,
      bindings: { "team" => { "source" => "_literal", "value" => [ { "name" => "Ada" } ] } }
    )
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    assert_equal "<li>Ada|</li>", output
  end

  test "public mode falls back on a syntax error and logs it" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% for x in %}", template_enabled: true
    )
    original_logger = Rails.logger
    log = StringIO.new
    Rails.logger = Logger.new(log)
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    assert_equal "<!-- dynamic block unavailable -->", output
    assert_match(/Liquid::SyntaxError/, log.string)
  ensure
    Rails.logger = original_logger
  end

  test "public mode falls back when a fetch block raises a plain error" do
    ActiveCanvas::DataSources.register(:boom) { fetch { raise ActiveRecord::StatementInvalid, "db gone" } }
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{{ x }}", template_enabled: true,
      bindings: { "x" => { "source" => "boom" } }
    )
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    assert_equal "<!-- dynamic block unavailable -->", output
  end

  test "public mode renders a silent source as nil instead of failing" do
    ActiveCanvas::DataSources.register(:flaky) do
      on_error :silent
      fetch { raise "db down" }
    end
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{% if promo %}yes{% else %}no{% endif %}", template_enabled: true,
      bindings: { "promo" => { "source" => "flaky" } }
    )
    assert_equal "no", ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
  end

  test "preview mode re-raises a fetch failure as TemplateRenderError" do
    ActiveCanvas::DataSources.register(:boom) { fetch { raise "db gone" } }
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "{{ x }}", template_enabled: true,
      bindings: { "x" => { "source" => "boom" } }
    )
    err = assert_raises(ActiveCanvas::DataSources::TemplateRenderError) do
      ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    end
    assert_equal "db gone", err.message
    assert_kind_of RuntimeError, err.original
  end

  test "preview mode reports the line of a syntax error" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "ok\n{% for x in %}", template_enabled: true
    )
    err = assert_raises(ActiveCanvas::DataSources::TemplateRenderError) do
      ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    end
    assert_equal 2, err.line
  end

  test "public mode does not escape twice and keeps escaped data inert" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "<p>{{ c }}</p>", template_enabled: true,
      bindings: { "c" => { "source" => "_literal", "value" => "<a href=\"https://evil\">x</a>" } }
    )
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    # Nokogiri re-serializes &quot; as a bare quote in text; the point is that no <a> tag exists.
    assert_includes output, "&lt;a href="
    refute_includes output, "<a "
    refute_includes output, "&amp;lt;"
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

  test "public mode renders a node that raises as empty and keeps the page" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type, template_enabled: true,
      content: "<p>a</p>{{ 1 | divided_by: 0 }}<p>b</p>"
    )
    assert_equal "<p>a</p><p>b</p>", ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
  end

  test "public mode falls back on a resource limit" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type, template_enabled: true,
      content: "{% for i in (1..10000) %}x{% endfor %}"
    )
    original = ActiveCanvas.config.template_render_score_limit
    ActiveCanvas.config.template_render_score_limit = 100
    assert_equal "<!-- dynamic block unavailable -->", ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
  ensure
    ActiveCanvas.config.template_render_score_limit = original
  end

  test "renders a data-ac-for table loop on the public page" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type, template_enabled: true,
      content: %(<table><tbody><tr data-ac-for="r in rows"><td>{{ r }}</td></tr></tbody></table>),
      bindings: { "rows" => { "source" => "_literal", "value" => %w[a b] } }
    )
    output = ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
    assert_includes output, "<tr><td>a</td></tr><tr><td>b</td></tr>"
    refute_includes output, "data-ac-for"
  end

  test "decodes entities in a data-ac-if expression" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type, template_enabled: true,
      content: %(<p data-ac-if="n &gt; 1">many</p>),
      bindings: { "n" => { "source" => "_literal", "value" => 5 } }
    )
    assert_equal "<p>many</p>", ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
  end

  test "preview mode surfaces a malformed directive as a TemplateRenderError" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type, template_enabled: true,
      content: %(<li data-ac-for="nope">x</li>)
    )
    err = assert_raises(ActiveCanvas::DataSources::TemplateRenderError) do
      ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
    end
    assert_match(/data-ac-for/, err.message)
  end

  test "preview mode returns plain rendered HTML without markers" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
    assert_equal "Hello World!", ActiveCanvas::TemplateRenderer.new(page, mode: :preview).render
  end

  test "public mode falls back on a malformed directive" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type, template_enabled: true,
      content: %(<li data-ac-for="nope">x</li>)
    )
    assert_equal "<!-- dynamic block unavailable -->", ActiveCanvas::TemplateRenderer.new(page, mode: :public).render
  end

  test "context is merged into the assigns available to render" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ item }}!", template_enabled: true
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public, context: { "item" => "World" })
    assert_equal "Hello World!", renderer.render
  end

  test "context names win over a binding of the same name" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!", template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "Binding" } }
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :public, context: { "name" => "Context" })
    assert_equal "Hello Context!", renderer.render
  end

  test "context is available to chip_values too" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: %(<span data-ac-id="1">{{ item }}</span>), template_enabled: true
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :preview, context: { "item" => "Widget" })
    assert_equal "Widget", renderer.chip_values(page.content)[:values]["1"]
  end

  test "context is honored in preview (strict) mode as well as public mode" do
    page = ActiveCanvas::Page.create!(
      title: "Dyn", page_type: @page_type,
      content: "Hello {{ name }}!", template_enabled: true
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :preview, context: { "name" => "Context" })
    assert_equal "Hello Context!", renderer.render
  end
end
