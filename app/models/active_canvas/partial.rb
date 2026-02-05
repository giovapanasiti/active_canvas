module ActiveCanvas
  class Partial < ApplicationRecord
    TYPES = %w[header footer].freeze

    validates :name, presence: true
    validates :partial_type, presence: true, inclusion: { in: TYPES }, uniqueness: true

    scope :active, -> { where(active: true) }

    after_save :compile_tailwind_css, if: :should_compile_css?

    class << self
      def header
        find_by(partial_type: "header")
      end

      def footer
        find_by(partial_type: "footer")
      end

      def active_header
        active.find_by(partial_type: "header")
      end

      def active_footer
        active.find_by(partial_type: "footer")
      end

      # Ensure both partials exist
      def ensure_defaults!
        find_or_create_by!(partial_type: "header") do |p|
          p.name = "Header"
        end
        find_or_create_by!(partial_type: "footer") do |p|
          p.name = "Footer"
        end
      end
    end

    def header?
      partial_type == "header"
    end

    def footer?
      partial_type == "footer"
    end

    def rendered_content
      content.to_s.html_safe
    end

    def full_css
      [compiled_css, content_css].compact.join("\n")
    end

    private

    def should_compile_css?
      saved_change_to_content? && content.present? && tailwind_available?
    end

    def tailwind_available?
      defined?(Tailwindcss)
    end

    def compile_tailwind_css
      return unless tailwind_available?

      begin
        compiled = Tailwindcss::Compiler.new(content: content.to_s).compile
        update_column(:compiled_css, compiled)
      rescue => e
        Rails.logger.error "[ActiveCanvas] Failed to compile Tailwind CSS for partial #{id}: #{e.message}"
      end
    end
  end
end
