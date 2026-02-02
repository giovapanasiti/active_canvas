require "active_canvas/version"
require "active_canvas/configuration"
require "active_canvas/engine"

module ActiveCanvas
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def config
      configuration
    end
  end
end
