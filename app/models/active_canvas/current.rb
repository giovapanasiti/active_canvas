module ActiveCanvas
  class Current < ActiveSupport::CurrentAttributes
    attribute :settings_cache
    # Display name of the admin user making the request; recorded on versions.
    attribute :editor

    def settings_cache
      super || (self.settings_cache = {})
    end
  end
end
