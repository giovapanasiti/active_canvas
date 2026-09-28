module ActiveCanvas
  # A bearer credential for the MCP endpoint. Only a SHA-256 digest is stored;
  # the plaintext is returned once by issue! and never again.
  class ApiToken < ApplicationRecord
    self.table_name = "active_canvas_api_tokens"

    SCOPES = %w[read write publish].freeze
    PREFIX = "ac_".freeze

    validates :name, presence: true
    validates :token_digest, presence: true, uniqueness: true
    validate :scopes_valid

    scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

    def self.issue!(name:, scopes:, expires_at: nil, created_by: nil)
      plaintext = PREFIX + SecureRandom.base58(40)
      token = create!(name: name, scopes: Array(scopes).map(&:to_s), expires_at: expires_at, created_by: created_by,
                      token_digest: digest(plaintext), token_prefix: plaintext.first(10))
      [ token, plaintext ]
    end

    def self.authenticate(plaintext)
      return nil if plaintext.blank? || !plaintext.start_with?(PREFIX)

      candidate = digest(plaintext)
      token = active.find_by(token_digest: candidate)
      token if token && ActiveSupport::SecurityUtils.secure_compare(token.token_digest, candidate)
    end

    def self.digest(plaintext)
      Digest::SHA256.hexdigest(plaintext)
    end

    def active?
      revoked_at.nil? && (expires_at.nil? || expires_at.future?)
    end

    def revoke!
      update!(revoked_at: Time.current)
    end

    def scope?(name)
      scopes.include?(name.to_s)
    end

    def touch_last_used!
      return if last_used_at && last_used_at > 1.minute.ago

      update_column(:last_used_at, Time.current)
    end

    private

    def scopes_valid
      list = Array(scopes)
      if list.empty? || (list - SCOPES).any?
        errors.add(:scopes, "must be a non-empty subset of #{SCOPES.join(', ')}")
      elsif list.include?("write") && !list.include?("read")
        errors.add(:scopes, "write requires read")
      elsif list.include?("publish") && !list.include?("write")
        errors.add(:scopes, "publish requires write")
      end
    end
  end
end
