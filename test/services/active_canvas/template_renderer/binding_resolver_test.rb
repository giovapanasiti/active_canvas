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
    assert_equal [ 1, 2, 3, 4 ], assigns["items"]
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
      fetch { [ article_class.new(1, "Post1"), article_class.new(2, "Post2") ] }
      auto_drop attributes: %i[id title]
    end
    bindings = { "posts" => { "source" => "posts" } }
    assigns = described_class.new(bindings).resolve
    assert_kind_of ActiveCanvas::AutoDrop, assigns["posts"].first
    assert_equal "Post1", assigns["posts"].first.invoke_drop("title")
  end

  test "rejects raw AR-like records when no Drop declared" do
    # This object has neither a drop_class nor auto_drop attributes to wrap
    # it with, so it lacks a Drop and to_liquid_value refuses it outright.
    ar_class = Struct.new(:id) do
      def attributes
        { id: id }
      end
    end
    ActiveCanvas::DataSources.register(:unsafe) { fetch { [ ar_class.new(1) ] } }
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

  test "a drop_class that is not a Liquid::Drop is refused" do
    not_a_drop = Class.new { def initialize(item); end }
    ActiveCanvas::DataSources.register(:bad_drop) do
      fetch { [ 1 ] }
      drop not_a_drop
    end
    assert_raises(ActiveCanvas::DataSources::UnsafeData) do
      described_class.new({ "x" => { "source" => "bad_drop" } }).resolve
    end
  end

  test "a real drop_class passes through" do
    drop_class = Class.new(::Liquid::Drop) do
      def initialize(item); super(); @item = item; end
      def doubled; @item * 2; end
    end
    ActiveCanvas::DataSources.register(:good_drop) do
      fetch { [ 21 ] }
      drop drop_class
    end
    assert_equal 42, described_class.new({ "x" => { "source" => "good_drop" } }).resolve["x"].first.invoke_drop("doubled")
  end

  test "a bare Struct result is wrapped by auto_drop, not iterated" do
    row = Struct.new(:id, :title)
    ActiveCanvas::DataSources.register(:one_row) do
      fetch { row.new(1, "<b>") }
      auto_drop attributes: %i[id]
    end
    result = described_class.new({ "x" => { "source" => "one_row" } }).resolve["x"]
    assert_kind_of ActiveCanvas::AutoDrop, result
    assert_nil result.invoke_drop("title")
  end

  test "a relation-like result is still iterated" do
    # [1, 2].each returns an Enumerator, which is neither an Array nor
    # responds to :to_ary, so it would not exercise the Array/to_ary guard.
    ActiveCanvas::DataSources.register(:rel) { fetch { [ 1, 2 ] } }
    assert_equal [ 1, 2 ], described_class.new({ "x" => { "source" => "rel" } }).resolve["x"]
  end

  test "a non-hash binding spec or params does not crash" do
    assert_raises(ActiveCanvas::DataSources::UnknownSource) { described_class.new({ "x" => "counts" }).resolve }
    assert_equal [ 1, 2, 3 ], described_class.new({ "x" => { "source" => "counts", "params" => "junk" } }).resolve["x"]
  end

  test "nil and existing drops bypass drop_class" do
    drop_class = Class.new(::Liquid::Drop) do
      def initialize(item); super(); @item = item; end
    end
    inner = ActiveCanvas::AutoDrop.new(Struct.new(:id).new(1), attributes: %i[id])
    ActiveCanvas::DataSources.register(:maybe) do
      fetch { [ nil, inner ] }
      drop drop_class
    end
    result = described_class.new({ "x" => { "source" => "maybe" } }).resolve["x"]
    assert_nil result[0]
    assert_same inner, result[1]
  end

  test "sample returns up to three plain rows for a list binding" do
    row = Struct.new(:id, :title, :author)
    author = Struct.new(:name)
    ActiveCanvas::DataSources.register(:posts) do
      fetch { (1..5).map { |i| row.new(i, "<b>Post #{i}</b>", author.new("Ann")) } }
      auto_drop attributes: %i[id title], associations: { author: %i[name] }
    end
    rows = described_class.new({ "posts" => { "source" => "posts" } }).sample("posts")
    assert_equal 3, rows.size
    assert_equal({ "id" => 1, "title" => "<b>Post 1</b>", "author" => { "name" => "Ann" } }, rows.first)
  end

  test "sample returns a scalar for a literal" do
    assert_equal "Hi & bye", described_class.new({ "t" => { "source" => "_literal", "value" => "Hi & bye" } }).sample("t")
  end

  test "sample raises UnknownSource for a binding that does not exist" do
    assert_raises(ActiveCanvas::DataSources::UnknownSource) { described_class.new({}).sample("nope") }
  end

  test "sample flattens a custom drop through Liquid's surface and skips methods with arguments" do
    base = Class.new(::Liquid::Drop) do
      def initialize(n); super(); @n = n; end
      def base_field; "base#{@n}"; end
    end
    child = Class.new(base) do
      def child_field; "child"; end
      def with_arg(x); x; end
      def me; self; end
    end
    ActiveCanvas::DataSources.register(:custom) do
      fetch { [ 1 ] }
      drop child
    end
    row = described_class.new({ "x" => { "source" => "custom" } }).sample("x").first
    assert_equal "base1", row["base_field"]
    assert_equal "child", row["child_field"]
    refute row.key?("with_arg")
    refute row.key?("to_liquid")
    assert_kind_of Hash, row["me"]            # recursion is capped, not infinite
  end

  test "sample never serializes an object outside the Liquid boundary" do
    leaky = Class.new(::Liquid::Drop) do
      def initialize(_); super(); end
      def record; ActiveCanvas::PageType.new(name: "secret"); end
    end
    ActiveCanvas::DataSources.register(:leaky) do
      fetch { [ 1 ] }
      drop leaky
    end
    row = described_class.new({ "x" => { "source" => "leaky" } }).sample("x").first
    assert_kind_of String, row["record"]
    refute_includes row["record"], "secret"
  end

  private

  def described_class
    ActiveCanvas::TemplateRenderer::BindingResolver
  end
end
