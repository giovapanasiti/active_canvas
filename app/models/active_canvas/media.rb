module ActiveCanvas
  class Media < ApplicationRecord
    # Use configured storage service if specified, otherwise default
    # Host app can set ActiveCanvas.config.storage_service = :public
    # and define a 'public' service in config/storage.yml for cloud storage
    has_one_attached :file, service: (ActiveCanvas.config.storage_service rescue nil) do |attachable|
      attachable.variant :thumb, resize_to_limit: [200, 200]
    end

    serialize :metadata, coder: JSON

    validates :filename, presence: true
    validates :file, presence: true, on: :create

    validate :acceptable_file, on: :create

    before_save :set_file_attributes, if: -> { file.attached? && file.blob.present? }
    after_commit :make_blob_public, on: [:create, :update], if: :should_make_public?

    scope :images, -> { where(content_type: ActiveCanvas.config.allowed_content_types) }
    scope :recent, -> { order(created_at: :desc) }

    def metadata
      super || {}
    end

    def url
      return nil unless file.attached?

      # For public blobs, use the public URL directly
      # For private blobs, use the redirect URL
      if file.blob.service.respond_to?(:public?) && file.blob.service.public?
        file.url
      else
        # Use permanent URL for local disk service or when public URL isn't available
        Rails.application.routes.url_helpers.rails_blob_url(
          file,
          only_path: true
        )
      end
    end

    def public_url
      return nil unless file.attached?

      # Returns the direct public URL for cloud storage
      # or the rails blob URL for local storage
      if file.blob.service.respond_to?(:url)
        file.url(expires_in: nil) rescue file.url
      else
        url
      end
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

      # Store blob metadata (dimensions for images) if available
      if file.blob.metadata.present?
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

    def should_make_public?
      file.attached? && ActiveCanvas.config.public_uploads
    end

    def make_blob_public
      return unless file.attached? && file.blob.present?

      blob = file.blob

      # For S3 and compatible services, set the blob to public-read ACL
      if blob.service.respond_to?(:bucket)
        begin
          # AWS S3
          if blob.service.respond_to?(:object_for)
            object = blob.service.object_for(blob.key)
            object.acl.put(acl: "public-read") if object.respond_to?(:acl)
            Rails.logger.info "ActiveCanvas: Set public-read ACL for #{blob.key}"
          end
        rescue Aws::S3::Errors::AccessDenied => e
          Rails.logger.warn "ActiveCanvas: Access denied setting public ACL. Ensure your S3 bucket allows public ACLs: #{e.message}"
        rescue => e
          Rails.logger.warn "ActiveCanvas: Could not set public ACL for blob #{blob.key}: #{e.message}"
        end
      end
    end
  end
end
