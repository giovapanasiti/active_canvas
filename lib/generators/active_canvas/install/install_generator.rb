module ActiveCanvas
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an ActiveCanvas initializer in your application."

      def copy_initializer
        template "initializer.rb", "config/initializers/active_canvas.rb"
      end

      def mount_engine
        routes_file = "config/routes.rb"
        if File.read(routes_file).include?("ActiveCanvas::Engine")
          say_status :skip, "ActiveCanvas::Engine already mounted", :yellow
        else
          route "mount ActiveCanvas::Engine => '/canvas'"
        end
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
