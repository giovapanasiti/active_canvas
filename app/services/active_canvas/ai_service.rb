module ActiveCanvas
  class AiService
    class << self
      def generate_text(prompt:, model: nil, context: nil, &block)
        AiConfiguration.configure_ruby_llm!
        model ||= Setting.ai_default_text_model

        chat = RubyLLM.chat(model: model)
        chat.with_instructions(build_system_prompt(context)) if context.present?

        if block_given?
          chat.ask(prompt, &block)
        else
          chat.ask(prompt)
        end
      end

      def generate_image(prompt:, model: nil)
        AiConfiguration.configure_ruby_llm!
        model ||= Setting.ai_default_image_model

        image = RubyLLM.paint(prompt, model: model)
        store_generated_image(image.url, prompt)
      end

      def screenshot_to_code(image_data:, model: nil, additional_prompt: nil)
        AiConfiguration.configure_ruby_llm!
        model ||= Setting.ai_default_vision_model
        framework = Setting.css_framework

        prompt = build_screenshot_prompt(framework, additional_prompt)

        chat = RubyLLM.chat(model: model)
        response = chat.ask(prompt, with: { image: image_data })

        extract_html(response.content)
      end

      private

      def build_system_prompt(context)
        framework = Setting.css_framework
        <<~PROMPT
          You are an expert web designer creating content for a visual page builder.
          Generate clean, semantic HTML using #{framework_name(framework)}.

          Guidelines:
          - Use proper semantic HTML5 elements (section, article, header, nav, etc.)
          - Include responsive design patterns
          - Return ONLY the HTML code, no explanations or markdown code blocks
          - Do not include <html>, <head>, or <body> tags - just the content
          - Use placeholder images from https://placehold.co/ when images are needed

          #{context}
        PROMPT
      end

      def build_screenshot_prompt(framework, additional)
        base = <<~PROMPT
          Convert this screenshot into clean HTML using #{framework_name(framework)}.

          Requirements:
          - Create semantic, accessible HTML5 structure
          - Make it fully responsive
          - Use placeholder images from https://placehold.co/ for any images
          - Match the layout, colors, and typography as closely as possible
          - Return ONLY the HTML code, no explanations or markdown code blocks
          - Do not include <html>, <head>, or <body> tags - just the content
        PROMPT

        additional.present? ? "#{base}\n\nAdditional instructions: #{additional}" : base
      end

      def framework_name(framework)
        case framework.to_s
        when "tailwind" then "Tailwind CSS classes"
        when "bootstrap5" then "Bootstrap 5 classes"
        else "vanilla CSS with inline styles"
        end
      end

      def store_generated_image(url, prompt)
        require "open-uri"

        filename = "ai_generated_#{Time.current.to_i}_#{SecureRandom.hex(4)}.png"
        tempfile = URI.parse(url).open

        media = Media.new(filename: filename)
        media.file.attach(io: tempfile, filename: filename, content_type: "image/png")
        media.metadata = { "ai_generated" => true, "ai_prompt" => prompt.truncate(500) }
        media.save!
        media
      ensure
        tempfile&.close
      end

      def extract_html(content)
        # Remove markdown code blocks if present
        html = content.to_s
        html = html.gsub(/```html\n?/i, "")
        html = html.gsub(/```\n?/, "")
        html.strip
      end
    end
  end
end
