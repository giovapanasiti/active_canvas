require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/active_canvas/install/install_generator"

module ActiveCanvas
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests ActiveCanvas::Generators::InstallGenerator
    destination File.expand_path("../../tmp/generator_test", __dir__)
    setup :prepare_destination

    setup do
      # Minimal app skeleton the generator touches.
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      File.write(File.join(destination_root, "Gemfile"), "source 'https://rubygems.org'\n")
    end

    test "runs non-interactively and skips the route with --defaults --skip-route" do
      gen = generator([], { "defaults" => true, "skip_route" => true })
      # Stub side-effectful actions so the test never shells out or hangs.
      def gen.rake(*); end
      def gen.run(*); end
      def gen.gem(*); end

      assert gen.options[:defaults],   "options[:defaults] must be true for non-interactive path"
      assert gen.options[:skip_route], "options[:skip_route] must be true to skip route injection"

      assert_nothing_raised { gen.invoke_all }

      assert_file "config/initializers/active_canvas.rb"
      assert_file "config/initializers/active_canvas.rb", /ActiveCanvas\.configure/
      assert_no_match(/ActiveCanvas::Engine/, File.read(File.join(destination_root, "config/routes.rb")))
    end
  end
end
