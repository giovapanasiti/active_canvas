namespace :active_canvas do
  namespace :install do
    desc "Copy migrations from active_canvas to application"
    task :migrations do
      source = ActiveCanvas::Engine.root.join("db/migrate")
      destination = ActiveRecord::Tasks::DatabaseTasks.migrations_paths.first

      ActiveRecord::Migration.copy(destination, { active_canvas: source })
    end
  end

  desc "Sync AI models from configured providers (OpenAI, Anthropic, OpenRouter)"
  task sync_models: :environment do
    # unless ActiveCanvas::AiConfiguration.ruby_llm_available?
    #   puts "RubyLLM gem is not available. Add 'ruby_llm' to your Gemfile."
    #   exit 1
    # end

    unless ActiveCanvas::AiConfiguration.configured?
      puts "No API keys configured."
      puts "Add keys via Settings > AI or set them directly:"
      puts "  ActiveCanvas::Setting.ai_openai_api_key = 'sk-...'"
      puts "  ActiveCanvas::Setting.ai_anthropic_api_key = 'sk-ant-...'"
      puts "  ActiveCanvas::Setting.ai_openrouter_api_key = 'sk-or-...'"
      exit 1
    end

    providers = ActiveCanvas::AiConfiguration.configured_providers
    puts "Configured providers: #{providers.join(', ')}"
    puts "Syncing models..."

    count = ActiveCanvas::AiModels.refresh!
    puts "Done! Synced #{count} models."

    # Show breakdown by type
    text_count = ActiveCanvas::AiModel.active.text_models.count
    image_count = ActiveCanvas::AiModel.active.image_models.count
    vision_count = ActiveCanvas::AiModel.active.vision_models.count

    puts ""
    puts "Breakdown:"
    puts "  Text models:   #{text_count}"
    puts "  Image models:  #{image_count}"
    puts "  Vision models: #{vision_count}"
  end

  desc "List synced AI models"
  task list_models: :environment do
    unless ActiveCanvas::AiModel.exists?
      puts "No models synced yet. Run: rails active_canvas:sync_models"
      exit 0
    end

    puts "=== Text/Chat Models ==="
    ActiveCanvas::AiModel.active.text_models.order(:provider, :name).each do |m|
      vision = m.supports_vision? ? " [vision]" : ""
      puts "  #{m.provider.ljust(12)} #{m.display_name}#{vision}"
    end

    puts ""
    puts "=== Image Models ==="
    ActiveCanvas::AiModel.active.image_models.order(:provider, :name).each do |m|
      puts "  #{m.provider.ljust(12)} #{m.display_name}"
    end

    puts ""
    puts "Total: #{ActiveCanvas::AiModel.active.count} models"
  end
end
