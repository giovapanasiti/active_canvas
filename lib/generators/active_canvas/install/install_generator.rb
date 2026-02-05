module ActiveCanvas
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Interactive setup wizard for ActiveCanvas"

      def welcome
        say ""
        say "=" * 60, :cyan
        say "  Welcome to ActiveCanvas Setup Wizard", :cyan
        say "=" * 60, :cyan
        say ""
        say "This wizard will help you set up ActiveCanvas in your Rails app."
        say ""
      end

      def install_migrations
        say "Step 1: Database Migrations", :yellow
        say "-" * 40

        if yes_no?("Copy ActiveCanvas migrations to your app?", default: true)
          rake "active_canvas:install:migrations"
          say "✓ Migrations copied", :green

          if yes_no?("Run migrations now?", default: true)
            rake "db:migrate"
            say "✓ Migrations completed", :green
          else
            say "→ Remember to run: bin/rails db:migrate", :yellow
          end
        else
          say "→ Skipped. Run later: bin/rails active_canvas:install:migrations", :yellow
        end
        say ""
      end

      def choose_css_framework
        say "Step 2: CSS Framework", :yellow
        say "-" * 40
        say "Choose which framework to use in the editor and public pages:"
        say ""
        say "  1. tailwind  - Tailwind CSS (recommended)"
        say "  2. bootstrap - Bootstrap 5"
        say "  3. none      - No framework"
        say ""

        framework = ask("Enter choice [tailwind]:")
        framework = "tailwind" if framework.blank?
        framework = framework.downcase.strip

        @css_framework = case framework
        when "tailwind", "1" then :tailwind
        when "bootstrap", "2" then :bootstrap5
        when "none", "3" then :none
        else :tailwind
        end

        if @css_framework == :tailwind
          setup_tailwind
        elsif @css_framework == :bootstrap5
          setup_bootstrap
        else
          say "→ No framework selected. You can change this in Admin > Settings.", :yellow
        end
        say ""
      end

      def configure_ai_features
        say "Step 3: AI Features (Optional)", :yellow
        say "-" * 40
        say "ActiveCanvas includes AI-powered features:"
        say "  • Text/HTML generation from prompts"
        say "  • Image generation"
        say "  • Screenshot to code conversion"
        say ""

        @setup_ai = yes_no?("Configure AI features?", default: true)

        if @setup_ai
          say ""
          say "Supported providers:", :cyan
          say "  • OpenAI (GPT-4, DALL-E)"
          say "  • Anthropic (Claude)"
          say "  • OpenRouter (Multiple models)"
          say ""
          say "API keys can be added later in Admin > Settings > AI"
          say ""

          if yes_no?("Add RubyLLM gem to Gemfile?", default: true)
            add_rubyllm_gem
          end
        else
          say "→ You can enable AI features later in Admin > Settings > AI", :yellow
        end
        say ""
      end

      def create_initializer
        say "Step 4: Configuration", :yellow
        say "-" * 40

        @mount_path = ask("Mount path [/canvas]:")
        @mount_path = "/canvas" if @mount_path.blank?
        @mount_path = "/#{@mount_path}" unless @mount_path.start_with?("/")

        template "initializer.rb", "config/initializers/active_canvas.rb"
        say "✓ Created config/initializers/active_canvas.rb", :green
        say ""
      end

      def mount_engine
        say "Step 5: Routes", :yellow
        say "-" * 40

        routes_file = "config/routes.rb"
        if File.read(routes_file).include?("ActiveCanvas::Engine")
          say "✓ ActiveCanvas::Engine already mounted", :green
        else
          route "mount ActiveCanvas::Engine => '#{@mount_path}'"
          say "✓ Mounted ActiveCanvas at #{@mount_path}", :green
        end
        say ""
      end

      def sync_ai_models
        if @setup_ai && yes_no?("Sync AI models now? (requires API keys in ENV)", default: false)
          say ""
          say "Syncing AI models...", :cyan
          rake "active_canvas:sync_models"
          say "✓ AI models synced", :green
        end
        say ""
      end

      def show_completion
        say "=" * 60, :green
        say "  Setup Complete!", :green
        say "=" * 60, :green
        say ""
        say "Next steps:", :yellow
        say ""
        say "  1. Start your Rails server:"
        say "     $ bin/rails server", :cyan
        say ""
        say "  2. Visit the admin panel:"
        say "     http://localhost:3000#{@mount_path}/admin", :cyan
        say ""
        say "  3. Configure authentication in:"
        say "     config/initializers/active_canvas.rb", :cyan
        say ""

        if @css_framework && @css_framework != :none
          say "  4. Your CSS framework (#{@css_framework}) is configured."
          say "     It will be loaded automatically in the editor.", :cyan
          say ""
        end

        if @setup_ai
          say "  5. Add AI API keys in Admin > Settings > AI", :cyan
          say "     Or set environment variables:"
          say "     OPENAI_API_KEY, ANTHROPIC_API_KEY, OPENROUTER_API_KEY", :cyan
          say ""
        end

        say "Documentation: https://github.com/giovapanasiti/active_canvas"
        say ""
      end

      private

      # Helper for yes/no prompts with clear defaults
      # @param question [String] The question to ask
      # @param default [Boolean] The default answer (true = Y, false = N)
      # @return [Boolean]
      def yes_no?(question, default: true)
        indicator = default ? "[Y/n]" : "[y/N]"
        answer = ask("#{question} #{indicator}")

        return default if answer.blank?

        answer.downcase.start_with?("y")
      end

      def setup_tailwind
        gemfile_content = File.read(Rails.root.join("Gemfile"))

        if gemfile_content.include?("tailwindcss-rails")
          say "✓ tailwindcss-rails gem already installed", :green
        else
          if yes_no?("Install tailwindcss-rails gem? (required for Tailwind)", default: true)
            gem "tailwindcss-rails"
            say "✓ Added tailwindcss-rails to Gemfile", :green

            if yes_no?("Run bundle install now?", default: true)
              run "bundle install"
              say "✓ Bundle installed", :green
            else
              say "→ Remember to run: bundle install", :yellow
            end
          else
            say "→ You'll need to add tailwindcss-rails gem manually", :yellow
          end
        end
      end

      def setup_bootstrap
        say "✓ Bootstrap 5 will be loaded from CDN", :green
      end

      def add_rubyllm_gem
        gemfile_path = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile_path)

        if gemfile_content.include?("ruby_llm")
          say "✓ ruby_llm gem already in Gemfile", :green
        else
          gem "ruby_llm"
          say "✓ Added ruby_llm to Gemfile", :green

          if yes_no?("Run bundle install now?", default: true)
            run "bundle install"
            say "✓ Bundle installed", :green
          else
            say "→ Remember to run: bundle install", :yellow
          end
        end
      end
    end
  end
end
