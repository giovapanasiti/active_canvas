module ActiveCanvas
  class PageVersion < ApplicationRecord
    belongs_to :page

    validates :version_number, presence: true, uniqueness: { scope: :page_id }

    before_validation :set_version_number, on: :create
    before_create :compute_diff
    before_create :set_content_sizes

    scope :recent, -> { order(version_number: :desc) }
    scope :oldest_first, -> { order(version_number: :asc) }

    def content_changed?
      content_before != content_after
    end

    def css_changed?
      css_before != css_after
    end

    def size_difference
      (content_size_after || 0) - (content_size_before || 0)
    end

    def size_difference_formatted
      diff = size_difference
      return "no change" if diff == 0
      diff > 0 ? "+#{diff} bytes" : "#{diff} bytes"
    end

    def changes_description
      changes = []
      changes << "content" if content_changed?
      changes << "CSS" if css_changed?
      changes.empty? ? "No changes" : "Changed: #{changes.join(', ')}"
    end

    private

    def set_version_number
      return if version_number.present?
      max_version = page.versions.maximum(:version_number) || 0
      self.version_number = max_version + 1
    end

    def compute_diff
      return unless content_before.present? && content_after.present?
      self.content_diff = generate_unified_diff(content_before, content_after)
    end

    def set_content_sizes
      self.content_size_before = content_before&.bytesize || 0
      self.content_size_after = content_after&.bytesize || 0
    end

    def generate_unified_diff(before, after)
      before_lines = before.to_s.lines
      after_lines = after.to_s.lines

      # Simple line-by-line diff
      diff_lines = []
      max_lines = [before_lines.size, after_lines.size].max

      max_lines.times do |i|
        before_line = before_lines[i]
        after_line = after_lines[i]

        if before_line == after_line
          diff_lines << "  #{before_line}"
        else
          diff_lines << "- #{before_line}" if before_line
          diff_lines << "+ #{after_line}" if after_line
        end
      end

      diff_lines.join
    end
  end
end
