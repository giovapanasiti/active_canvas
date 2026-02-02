module ActiveCanvas
  class Setting < ApplicationRecord
    validates :key, presence: true, uniqueness: true

    CSS_FRAMEWORKS = {
      "tailwind" => {
        name: "Tailwind CSS",
        url: "https://cdn.tailwindcss.com",
        type: :script
      },
      "bootstrap5" => {
        name: "Bootstrap 5",
        url: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css",
        type: :stylesheet
      },
      "custom" => {
        name: "Custom CSS (no framework)",
        url: nil,
        type: nil
      }
    }.freeze

    class << self
      def get(key)
        find_by(key: key)&.value
      end

      def set(key, value)
        setting = find_or_initialize_by(key: key)
        setting.update!(value: value)
        value
      end

      def homepage_page_id
        get("homepage_page_id")&.to_i
      end

      def homepage_page_id=(page_id)
        set("homepage_page_id", page_id.presence)
      end

      def homepage
        page_id = homepage_page_id
        return nil unless page_id&.positive?

        Page.published.find_by(id: page_id)
      end

      def css_framework
        get("css_framework") || ActiveCanvas.config.css_framework.to_s
      end

      def css_framework=(framework)
        set("css_framework", framework.presence)
      end

      def css_framework_config
        CSS_FRAMEWORKS[css_framework] || CSS_FRAMEWORKS["custom"]
      end

      def css_framework_url
        css_framework_config[:url]
      end

      def css_framework_type
        css_framework_config[:type]
      end

      def global_css
        get("global_css") || ""
      end

      def global_css=(css)
        set("global_css", css)
      end

      def global_js
        get("global_js") || ""
      end

      def global_js=(js)
        set("global_js", js)
      end
    end
  end
end
