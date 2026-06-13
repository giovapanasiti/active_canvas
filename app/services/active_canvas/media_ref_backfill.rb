require "base64"
require "json"

module ActiveCanvas
  # One-time, best-effort backfill: rewrites legacy <img> tags whose src is an
  # Active Storage blob redirect URL into stable <img data-ac-media-id="N"> refs
  # that ContentRenderer can resolve at render time. Idempotent; logs unmatched.
  #
  # Recovers the blob id by decoding the signed_id payload directly, bypassing
  # the expiry check (this is our own data) so already-rotted URLs are healed.
  class MediaRefBackfill
    BLOB_URL_RE = %r{active_storage/blobs/(?:redirect|proxy)/([^/]+)/[^/]+\z}

    def self.run(logger: Rails.logger)
      new(logger).run
    end

    def initialize(logger)
      @logger = logger
    end

    def run
      ActiveCanvas::Page.find_each do |page|
        content = page.content
        next if content.blank?

        fragment = Nokogiri::HTML5.fragment(content)
        changed = false

        fragment.css("img").each do |img|
          next if img["data-ac-media-id"].present?

          src = img["src"].to_s
          next unless src.match?(BLOB_URL_RE)

          media_id = media_id_for(src)
          if media_id
            img["data-ac-media-id"] = media_id.to_s
            changed = true
          else
            @logger.warn("[ActiveCanvas] backfill: could not match media for #{src} on page #{page.id}")
          end
        end

        # update_columns: skip sanitize + version callbacks; we only add a data-* attr.
        page.update_columns(content: fragment.to_html) if changed
      end
    end

    private

    def media_id_for(src)
      match = src.match(BLOB_URL_RE)
      return nil unless match

      blob_id = blob_id_from_signed_id(match[1])
      return nil unless blob_id

      ActiveStorage::Attachment
        .where(record_type: "ActiveCanvas::Media", name: "file", blob_id: blob_id)
        .limit(1)
        .pick(:record_id)
    end

    # Decodes "<base64 payload>--<hmac>" into the blob id. The payload base64
    # decodes to {"_rails":{"data":<blob_id>,"exp":...,"pur":"blob_id"}}.
    def blob_id_from_signed_id(signed_id)
      payload = signed_id.to_s.split("--").first
      return nil if payload.blank?

      data = JSON.parse(Base64.decode64(payload))
      data.dig("_rails", "data")
    rescue StandardError
      nil
    end
  end
end
