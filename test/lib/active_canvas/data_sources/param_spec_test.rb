require "test_helper"

class ActiveCanvas::DataSources::ParamSpecTest < ActiveSupport::TestCase
  def build(**opts)
    ActiveCanvas::DataSources::ParamSpec.new(:foo, source_name: :test_source, **opts)
  end

  test "integer type coerces string to integer" do
    spec = build(type: :integer)
    assert_equal 5, spec.coerce("5")
  end

  test "integer type rejects non-numeric strings" do
    spec = build(type: :integer)
    err = assert_raises(ActiveCanvas::DataSources::InvalidParam) { spec.coerce("abc") }
    assert_match(/not a valid integer/, err.message)
  end

  test "string type coerces values to string" do
    spec = build(type: :string)
    assert_equal "5", spec.coerce(5)
  end

  test "boolean type coerces truthy/falsey" do
    spec = build(type: :boolean)
    assert_equal true,  spec.coerce("true")
    assert_equal false, spec.coerce("false")
    assert_equal true,  spec.coerce(1)
    assert_equal false, spec.coerce(0)
  end

  test "default applied when value is nil" do
    spec = build(type: :integer, default: 5)
    assert_equal 5, spec.coerce(nil)
  end

  test "default applied when value missing (not in hash)" do
    spec = build(type: :integer, default: 5)
    assert_equal 5, spec.resolve({})
  end

  test "range constraint enforced after coercion" do
    spec = build(type: :integer, range: 1..10)
    assert_equal 5, spec.coerce("5")
    assert_raises(ActiveCanvas::DataSources::InvalidParam) { spec.coerce("99") }
  end

  test "allowed list enforced after coercion" do
    spec = build(type: :string, allowed: %w[news blog])
    assert_equal "news", spec.coerce("news")
    assert_raises(ActiveCanvas::DataSources::InvalidParam) { spec.coerce("invalid") }
  end

  test "nil with no default returns nil" do
    spec = build(type: :string)
    assert_nil spec.coerce(nil)
  end
end
