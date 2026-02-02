module ActiveCanvas
  class Media < ApplicationRecord
    has_one_attached :file

    serialize :metadata, coder: JSON

    validates :filename, presence: true
    validates :file, presence: true, on: :create

    validate :acceptable_file, on: :create

    before_save :set_file_attributes, if: -> { file.attached? && file.blob.present? }

    scope :images, -> { where(content_type: ActiveCanvas.config.allowed_content_types) }
    scope :recent, -> { order(created_at: :desc) }

    def metadata
      super || {}
    end

    def url
      return nil unless file.attached?

      Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
    end

    def as_json_for_editor
      {
        id: id,
        src: url,
        name: filename,
        type: content_type,
        width: metadata["width"],
        height: metadata["height"]
      }
    end

    private

    def set_file_attributes
      self.content_type = file.blob.content_type
      self.byte_size = file.blob.byte_size
      self.filename = file.blob.filename.to_s if filename.blank?

      if file.blob.analyzable? && file.blob.analyzed?
        self.metadata = file.blob.metadata
      end
    end

    def acceptable_file
      return unless file.attached?

      unless ActiveCanvas.config.allowed_content_types.include?(file.content_type)
        errors.add(:file, "must be an image (JPEG, PNG, GIF, WebP, or SVG)")
      end

      if file.blob.byte_size > ActiveCanvas.config.max_upload_size
        errors.add(:file, "is too large (maximum is #{ActiveCanvas.config.max_upload_size / 1.megabyte}MB)")
      end
    end
  end
end
