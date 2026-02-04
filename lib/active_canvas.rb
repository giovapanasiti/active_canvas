require "active_canvas/version"
require "active_canvas/configuration"
require "active_canvas/engine"

# Load RubyLLM if available for AI features
begin
  require "ruby_llm"
rescue LoadError
  # RubyLLM is optional - AI features will be disabled if not available
end

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
