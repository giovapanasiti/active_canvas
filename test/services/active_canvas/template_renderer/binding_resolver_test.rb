require "test_helper"

class ActiveCanvas::TemplateRenderer::BindingResolverTest < ActiveSupport::TestCase
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    ActiveCanvas::DataSources.register(:counts) do
      param :n, type: :integer, default: 3
      fetch { |n:| (1..n).to_a }
    end
  end

  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "resolves literal binding to its value" do
    bindings = { "title" => { "source" => "_literal", "value" => "Welcome" } }
    assigns = described_class.new(bindings).resolve
    assert_equal "Welcome", assigns["title"]
  end

  test "resolves data source binding with params" do
    bindings = { "items" => { "source" => "counts", "params" => { "n" => 4 } } }
    assigns = described_class.new(bindings).resolve
    assert_equal [1, 2, 3, 4], assigns["items"]
  end

  test "unknown source raises UnknownSource" do
    bindings = { "x" => { "source" => "nope" } }
    assert_raises(ActiveCanvas::DataSources::UnknownSource) { described_class.new(bindings).resolve }
  end

  test "invalid param raises InvalidParam" do
    ActiveCanvas::DataSources.register(:bounded) do
      param :n, type: :integer, range: 1..5
      fetch { |n:| n }
    end
    bindings = { "x" => { "source" => "bounded", "params" => { "n" => 99 } } }
    assert_raises(ActiveCanvas::DataSources::InvalidParam) { described_class.new(bindings).resolve }
  end

  test "wraps AR-like records via auto_drop when source declares it" do
    article_class = Struct.new(:id, :title)
    ActiveCanvas::DataSources.register(:posts) do
      fetch { [article_class.new(1, "Post1"), article_class.new(2, "Post2")] }
      auto_drop attributes: %i[id title]
    end
    bindings = { "posts" => { "source" => "posts" } }
    assigns = described_class.new(bindings).resolve
    assert_kind_of ActiveCanvas::AutoDrop, assigns["posts"].first
    assert_equal "Post1", assigns["posts"].first.invoke_drop("title")
  end

  test "rejects raw AR-like records when no Drop declared" do
    # Plain Ruby Struct does NOT respond to :attributes (that's AR/AM specific).
    # We explicitly define attributes to simulate an AR-like object so the
    # unsafe? check fires even without ActiveRecord::Base loaded.
    ar_class = Struct.new(:id) do
      def attributes
        { id: id }
      end
    end
    ActiveCanvas::DataSources.register(:unsafe) { fetch { [ar_class.new(1)] } }
    bindings = { "x" => { "source" => "unsafe" } }
    assert_raises(ActiveCanvas::DataSources::UnsafeData) { described_class.new(bindings).resolve }
  end

  test "auto_drop html: attributes reach Liquid unescaped" do
    row = Struct.new(:id, :body)
    ActiveCanvas::DataSources.register(:posts) do
      fetch { [ row.new(1, "<p>keep me</p>") ] }
      auto_drop attributes: %i[id body], html: %i[body]
    end
    drop = described_class.new({ "posts" => { "source" => "posts" } }).resolve["posts"].first
    assert_equal "<p>keep me</p>", drop.invoke_drop("body")
  end


  test "escapes literal strings" do
    bindings = { "title" => { "source" => "_literal", "value" => "<b>x</b> & y" } }
    assert_equal "&lt;b&gt;x&lt;/b&gt; &amp; y", described_class.new(bindings).resolve["title"]
  end

  test "escapes strings nested in literal arrays and hashes" do
    bindings = { "list" => { "source" => "_literal", "value" => [ "<i>", { "k" => "<u>" } ] } }
    list = described_class.new(bindings).resolve["list"]
    assert_equal "&lt;i&gt;", list[0]
    assert_equal "&lt;u&gt;", list[1]["k"]
  end

  test "html_safe strings pass through untouched" do
    ActiveCanvas::DataSources.register(:html) { fetch { "<b>ok</b>".html_safe } }
    assert_equal "<b>ok</b>", described_class.new({ "x" => { "source" => "html" } }).resolve["x"]
  end

  test "stringifies hash keys so Liquid can reach them" do
    ActiveCanvas::DataSources.register(:site) { fetch { { name: "Acme", nested: { city: "Rome" } } } }
    assigns = described_class.new({ "site" => { "source" => "site" } }).resolve
    assert_equal "Acme", assigns["site"]["name"]
    assert_equal "Rome", assigns["site"]["nested"]["city"]
  end

  test "rejects a plain Ruby object returned without a Drop" do
    row = Struct.new(:id)
    ActiveCanvas::DataSources.register(:poro) { fetch { [ row.new(1) ] } }
    assert_raises(ActiveCanvas::DataSources::UnsafeData) do
      described_class.new({ "x" => { "source" => "poro" } }).resolve
    end
  end

  test "rejects an object nested inside a Hash" do
    row = Struct.new(:id)
    ActiveCanvas::DataSources.register(:nested) { fetch { { user: row.new(1) } } }
    assert_raises(ActiveCanvas::DataSources::UnsafeData) do
      described_class.new({ "x" => { "source" => "nested" } }).resolve
    end
  end

  test "auto_drop wraps records but leaves scalars alone" do
    row = Struct.new(:id, :title)
    ActiveCanvas::DataSources.register(:mixed) do
      fetch { [ row.new(1, "a"), 42 ] }
      auto_drop attributes: %i[id title]
    end
    result = described_class.new({ "x" => { "source" => "mixed" } }).resolve["x"]
    assert_kind_of ActiveCanvas::AutoDrop, result[0]
    assert_equal 42, result[1]
  end

  test "a silent source that raises resolves to nil when silent_errors is on" do
    ActiveCanvas::DataSources.register(:flaky) do
      on_error :silent
      fetch { raise "db down" }
    end
    assigns = described_class.new({ "x" => { "source" => "flaky" } }, silent_errors: true).resolve
    assert_nil assigns["x"]
  end

  test "a silent source still raises when silent_errors is off (preview)" do
    ActiveCanvas::DataSources.register(:flaky) do
      on_error :silent
      fetch { raise "db down" }
    end
    assert_raises(RuntimeError) { described_class.new({ "x" => { "source" => "flaky" } }).resolve }
  end

  test "a raising source without on_error :silent raises even with silent_errors on" do
    ActiveCanvas::DataSources.register(:loud) { fetch { raise "db down" } }
    assert_raises(RuntimeError) do
      described_class.new({ "x" => { "source" => "loud" } }, silent_errors: true).resolve
    end
  end
  private

  def described_class
    ActiveCanvas::TemplateRenderer::BindingResolver
  end
end
