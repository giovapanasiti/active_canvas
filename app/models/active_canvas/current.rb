module ActiveCanvas
  class Current < ActiveSupport::CurrentAttributes
    attribute :settings_cache

    def settings_cache
      super || (self.settings_cache = {})
    end
  end
end
