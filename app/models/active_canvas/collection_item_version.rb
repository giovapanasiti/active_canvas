module ActiveCanvas
  class CollectionItemVersion < ApplicationRecord
    belongs_to :collection_item

    attribute :data, default: {}

    validates :version_number, presence: true, uniqueness: { scope: :collection_item_id }

    before_validation :set_version_number, on: :create

    private

    def set_version_number
      return if version_number.present?
      self.version_number = (collection_item.versions.maximum(:version_number) || 0) + 1
    end
  end
end
