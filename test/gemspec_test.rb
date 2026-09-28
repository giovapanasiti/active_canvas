require "test_helper"

class GemspecTest < ActiveSupport::TestCase
  # Lexxy switches to Action Text's editor-adapter mode on Rails 8.2+, which
  # changes every rich text editor in the host app (see the gemspec comment).
  test "rails dependency is capped below 8.2" do
    spec = Gem::Specification.load(File.expand_path("../active_canvas.gemspec", __dir__))
    rails = spec.runtime_dependencies.find { |dep| dep.name == "rails" }

    assert rails.requirement.satisfied_by?(Gem::Version.new("8.1.9"))
    refute rails.requirement.satisfied_by?(Gem::Version.new("8.2.0"))
  end
end
