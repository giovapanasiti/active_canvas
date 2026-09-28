require "test_helper"

class ActiveCanvas::ApiTokenTest < ActiveSupport::TestCase
  test "issue! returns the plaintext once and stores only a digest" do
    token, plaintext = ActiveCanvas::ApiToken.issue!(name: "ci", scopes: %w[read])
    assert_match(/\Aac_[1-9A-HJ-NP-Za-km-z]{40}\z/, plaintext)
    assert_equal plaintext.first(10), token.token_prefix
    refute_includes token.attributes.values.map(&:to_s), plaintext
    assert_equal Digest::SHA256.hexdigest(plaintext), token.token_digest
  end

  test "authenticate finds active tokens only" do
    token, plaintext = ActiveCanvas::ApiToken.issue!(name: "ci", scopes: %w[read])
    assert_equal token, ActiveCanvas::ApiToken.authenticate(plaintext)
    assert_nil ActiveCanvas::ApiToken.authenticate("ac_wrong")
    assert_nil ActiveCanvas::ApiToken.authenticate(nil)
    token.revoke!
    assert_nil ActiveCanvas::ApiToken.authenticate(plaintext)
  end

  test "expired tokens do not authenticate" do
    token, plaintext = ActiveCanvas::ApiToken.issue!(name: "ci", scopes: %w[read], expires_at: 1.minute.from_now)
    travel 2.minutes do
      assert_nil ActiveCanvas::ApiToken.authenticate(plaintext)
      refute token.reload.active?
    end
  end

  test "scopes must be known, non-empty and cumulative" do
    assert_raises(ActiveRecord::RecordInvalid) { ActiveCanvas::ApiToken.issue!(name: "x", scopes: []) }
    assert_raises(ActiveRecord::RecordInvalid) { ActiveCanvas::ApiToken.issue!(name: "x", scopes: %w[admin]) }
    assert_raises(ActiveRecord::RecordInvalid) { ActiveCanvas::ApiToken.issue!(name: "x", scopes: %w[write]) }
    assert_raises(ActiveRecord::RecordInvalid) { ActiveCanvas::ApiToken.issue!(name: "x", scopes: %w[read publish]) }
    token, = ActiveCanvas::ApiToken.issue!(name: "x", scopes: %w[read write publish])
    assert token.scope?(:publish)
  end

  test "name is required" do
    assert_raises(ActiveRecord::RecordInvalid) { ActiveCanvas::ApiToken.issue!(name: "", scopes: %w[read]) }
  end

  test "touch_last_used! throttles writes to once a minute" do
    token, = ActiveCanvas::ApiToken.issue!(name: "ci", scopes: %w[read])
    token.touch_last_used!
    first = token.reload.last_used_at
    travel 30.seconds do
      token.touch_last_used!
      assert_equal first.to_i, token.reload.last_used_at.to_i
    end
    travel 2.minutes do
      token.touch_last_used!
      assert_operator token.reload.last_used_at, :>, first
    end
  end
end
