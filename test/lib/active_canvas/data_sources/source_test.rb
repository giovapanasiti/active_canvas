require "test_helper"
require "liquid"

class ActiveCanvas::DataSources::SourceTest < ActiveSupport::TestCase
  def build_source(&blk)
    builder = ActiveCanvas::DataSources::Registration.new(:fixtures)
    builder.instance_eval(&blk)
    builder.to_source
  end

  test "stores name and fetch block" do
    source = build_source do
      fetch { [1, 2, 3] }
    end
    assert_equal :fixtures, source.name
    assert_equal [1, 2, 3], source.call({})
  end

  test "validates params before calling fetch" do
    source = build_source do
      param :limit, type: :integer, default: 5, range: 1..10
      fetch { |limit:| Array.new(limit, "x") }
    end
    assert_equal ["x", "x"], source.call(limit: 2)
    assert_raises(ActiveCanvas::DataSources::InvalidParam) { source.call(limit: 99) }
  end

  test "applies defaults when params missing" do
    source = build_source do
      param :limit, type: :integer, default: 3
      fetch { |limit:| limit }
    end
    assert_equal 3, source.call({})
  end

  test "on_error defaults to :raise" do
    source = build_source { fetch { [] } }
    assert_equal :raise, source.on_error
  end

  test "on_error can be set to :silent" do
    source = build_source do
      on_error :silent
      fetch { [] }
    end
    assert_equal :silent, source.on_error
  end

  test "auto_drop stores attribute list" do
    source = build_source do
      param :limit, type: :integer, default: 1
      fetch { |limit:| [Struct.new(:id, :title).new(1, "x")] * limit }
      auto_drop attributes: %i[id title]
    end
    assert_equal({ attributes: %i[id title], associations: {} }, source.auto_drop_config)
  end

  test "explicit drop class stored" do
    drop_class = Class.new(Liquid::Drop)
    source = build_source do
      fetch { [] }
      drop drop_class
    end
    assert_equal drop_class, source.drop_class
  end

  test "fetch is required" do
    err = assert_raises(ArgumentError) do
      ActiveCanvas::DataSources::Registration.new(:nofetch).to_source
    end
    assert_match(/fetch block required/, err.message)
  end
end
