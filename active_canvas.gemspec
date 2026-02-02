require_relative "lib/active_canvas/version"

Gem::Specification.new do |spec|
  spec.name        = "active_canvas"
  spec.version     = ActiveCanvas::VERSION
  spec.authors     = [ "Giovanni Panasiti" ]
  spec.email       = [ "giova.panasiti@gmail.com" ]
  spec.homepage    = "https://github.com/giovannip/active_canvas"
  spec.summary     = "A mountable Rails CMS engine for managing static pages"
  spec.description = "ActiveCanvas provides a simple CMS for creating and managing static pages with an admin interface"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/giovannip/active_canvas"
  spec.metadata["changelog_uri"] = "https://github.com/giovannip/active_canvas/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.0"
end
