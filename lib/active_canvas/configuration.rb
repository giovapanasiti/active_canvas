module ActiveCanvas
  class Configuration
    # Authentication callback for public pages
    # Set to a proc/lambda that will be called as a before_action
    # Example: config.authenticate_public = -> { redirect_to login_path unless current_user }
    attr_accessor :authenticate_public

    # Authentication callback for admin pages
    # Set to a proc/lambda or method name symbol
    # Example: config.authenticate_admin = :authenticate_admin_user!
    # Example: config.authenticate_admin = -> { redirect_to login_path unless current_user&.admin? }
    attr_accessor :authenticate_admin

    # Current user method name (used by AI features, etc.)
    # Example: config.current_user_method = :current_user
    attr_accessor :current_user_method

    def initialize
      @authenticate_public = nil
      @authenticate_admin = nil
      @current_user_method = :current_user
    end
  end

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
