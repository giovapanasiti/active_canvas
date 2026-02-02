module ActiveCanvas
  class Setting < ApplicationRecord
    validates :key, presence: true, uniqueness: true

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
    end
  end
end
