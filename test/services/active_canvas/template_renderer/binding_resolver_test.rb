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

  private

  def described_class
    ActiveCanvas::TemplateRenderer::BindingResolver
  end
end
