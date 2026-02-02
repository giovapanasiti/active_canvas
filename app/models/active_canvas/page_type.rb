module ActiveCanvas
  class PageType < ApplicationRecord
    has_many :pages, dependent: :restrict_with_error

    validates :name, presence: true
    validates :key, presence: true, uniqueness: true

    before_validation :generate_key, on: :create

    def self.default
      find_or_create_by!(key: "page") do |pt|
        pt.name = "Page"
      end
    end

    private

    def generate_key
      self.key ||= name&.parameterize&.underscore
    end
  end
end
