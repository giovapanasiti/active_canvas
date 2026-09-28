require_relative "lib/active_canvas/version"

Gem::Specification.new do |spec|
  spec.name        = "active_canvas"
  spec.version     = ActiveCanvas::VERSION
  spec.authors     = [ "Giovanni Panasiti" ]
  spec.email       = [ "giova.panasiti@gmail.com" ]
  spec.homepage    = "https://github.com/giovapanasiti/active_canvas"
  spec.summary     = "A mountable Rails CMS engine for managing static pages"
  spec.description = "ActiveCanvas provides a simple CMS for creating and managing static pages with an admin interface"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/giovapanasiti/active_canvas"
  spec.metadata["changelog_uri"] = "https://github.com/giovapanasiti/active_canvas/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  # Capped below 8.2: on Rails 8.2+ Lexxy registers itself as Action Text's
  # editor adapter (app.config.action_text.editor = :lexxy), which changes
  # every rich text editor in the host app, and ActiveCanvas's opt-out
  # (config.lexxy.override_action_text_defaults = false) only covers the
  # Rails 8.0/8.1 helper-override mode. Not supported yet.
  spec.add_dependency "rails", ">= 8.0.0", "< 8.2"
  spec.add_dependency "lexxy", ">= 0.9.33", "< 1.0"
  spec.add_dependency "ruby_llm", ">= 1.0"
  spec.add_dependency "liquid", ">= 5.4"
  spec.add_dependency "csv", ">= 3.0"
  spec.add_dependency "mcp", ">= 1.6.1", "< 2"
  spec.add_dependency "rubyzip", ">= 2.3"
end
