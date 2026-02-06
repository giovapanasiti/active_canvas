module ActiveCanvas
  module RateLimitable
    extend ActiveSupport::Concern

    class RateLimitExceeded < StandardError; end

    included do
      rescue_from RateLimitExceeded, with: :render_rate_limit_exceeded
    end

    private

    def check_rate_limit(namespace: "default", limit: nil, window: 1.minute)
      limit ||= ActiveCanvas.config.ai_rate_limit_per_minute
      cache_key = rate_limit_cache_key(namespace)

      count = increment_rate_limit(cache_key, window)

      if count > limit
        Rails.logger.warn "[ActiveCanvas] Rate limit exceeded for #{request.remote_ip} (#{count}/#{limit} in #{window})"
        raise RateLimitExceeded, "Rate limit exceeded. Please try again later."
      end
    end

    def rate_limit_cache_key(namespace)
      "active_canvas:rate_limit:#{namespace}:#{request.remote_ip}"
    end

    def increment_rate_limit(cache_key, window)
      if Rails.cache.respond_to?(:increment)
        # Redis or other cache with atomic increment
        count = Rails.cache.increment(cache_key, 1, expires_in: window, raw: true)
        count.to_i
      else
        # Fallback for memory store or other caches without atomic increment
        current = Rails.cache.read(cache_key).to_i
        Rails.cache.write(cache_key, current + 1, expires_in: window)
        current + 1
      end
    end

    def render_rate_limit_exceeded(exception)
      respond_to do |format|
        format.html { render plain: exception.message, status: :too_many_requests }
        format.json { render json: { error: exception.message }, status: :too_many_requests }
      end
    end

    # Verify request origin for CSRF protection on streaming endpoints
    def verify_request_origin
      # Same-origin requests don't have an Origin header
      return if request.origin.blank?

      # Build list of allowed origins
      allowed_origins = []

      # Current host
      host = request.host
      port = request.port

      if request.ssl?
        allowed_origins << "https://#{host}"
        allowed_origins << "https://#{host}:#{port}" unless port == 443
      else
        allowed_origins << "http://#{host}"
        allowed_origins << "http://#{host}:#{port}" unless port == 80
      end

      unless allowed_origins.include?(request.origin)
        Rails.logger.warn "[ActiveCanvas] Origin verification failed: #{request.origin} not in #{allowed_origins}"
        render json: { error: "Invalid request origin" }, status: :forbidden
      end
    end
  end
end
