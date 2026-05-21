# test/performance/active_canvas/renderer_bench_test.rb
require "test_helper"
require "benchmark"

class ActiveCanvas::RendererBenchTest < ActiveSupport::TestCase
  # Skipped by default. Run explicitly:
  #   AC_BENCH=1 bin/rails test test/performance/active_canvas/renderer_bench_test.rb
  def setup
    skip "set AC_BENCH=1 to run perf benchmarks" unless ENV["AC_BENCH"]
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.find_or_create_by!(name: "Test")
  end
  def teardown; ActiveCanvas::DataSources.reset_for_testing! if ENV["AC_BENCH"]; end

  test "renders 50KB template with 100 chips in under 100ms (preview mode)" do
    chip = "{{ a }} " * 100              # 100 chips, ~600 bytes
    filler = "lorem ipsum " * 5_000      # padding to ~50KB
    page = ActiveCanvas::Page.create!(
      title: "perf", page_type: @page_type,
      content: filler + chip,
      template_enabled: true,
      bindings: { "a" => { "source" => "_literal", "value" => "x" } }
    )
    renderer = ActiveCanvas::TemplateRenderer.new(page, mode: :preview)
    elapsed = Benchmark.realtime { renderer.render }
    # Goal is regression detection, not absolute speed benchmarking.
    # Threshold set to 100ms to accommodate hardware variance.
    assert elapsed < 0.100, "render took #{(elapsed*1000).round}ms, expected <100ms"
  end
end
