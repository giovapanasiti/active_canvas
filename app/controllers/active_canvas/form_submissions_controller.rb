module ActiveCanvas
  class FormSubmissionsController < ApplicationController
    MAX_VALUE_BYTES = 10.kilobytes
    MAX_PAYLOAD_BYTES = 64.kilobytes

    # The signed ac_token + origin check replace Rails CSRF for this public,
    # CMS-content-originated endpoint.
    skip_before_action :verify_authenticity_token, raise: false

    def create
      return head :forbidden unless trusted_origin?

      payload = verified_token
      return head :unprocessable_entity unless payload

      page = Page.published.find_by(id: payload["page_id"])
      return head :not_found unless page

      form_key = payload["form_key"]
      return fake_success(page, form_key) if params[:ac_website].present?
      return reject(page, form_key, "too_fast") if too_fast?(payload)
      return head :too_many_requests if rate_limited?
      return head :content_too_large if oversized?

      schema = FormSchema.derive(page.content, form_key)
      return head :unprocessable_entity unless schema

      data = params.permit(*schema.fields).to_h
      return reject(page, form_key, "missing_fields") if schema.required.any? { |field| data[field].blank? }

      submission = page.form_submissions.create!(
        form_key: form_key, data: data,
        ip: request.remote_ip, user_agent: request.user_agent.to_s.first(500)
      )
      notify(submission)
      redirect_to success_path(page, form_key)
    end

    private

    def trusted_origin?
      source = request.origin.presence || request.referer.presence
      return false unless source

      URI.parse(source).host == request.host
    rescue URI::InvalidURIError
      false
    end

    def verified_token
      FormStamper.verifier.verify(params[:ac_token].to_s)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def too_fast?(payload)
      Time.current.to_f - payload["issued_at"].to_f < ActiveCanvas.config.form_min_submit_seconds
    end

    def rate_limited?
      key = "active_canvas:form_rate:#{request.remote_ip}"
      count = Rails.cache.increment(key, 1, expires_in: 1.minute)
      count.to_i > ActiveCanvas.config.form_rate_limit_per_minute
    end

    def oversized?
      request.content_length.to_i > MAX_PAYLOAD_BYTES ||
        params.to_unsafe_h.values.any? { |value| value.is_a?(String) && value.bytesize > MAX_VALUE_BYTES }
    end

    def fake_success(page, form_key)
      redirect_to success_path(page, form_key)
    end

    def reject(page, form_key, reason)
      redirect_to public_page_path(page.slug, ac_form_error: reason, ac_form: form_key, anchor: form_key)
    end

    def success_path(page, form_key)
      public_page_path(page.slug, ac_submitted: form_key, anchor: form_key)
    end

    def notify(submission)
      ActiveSupport::Notifications.instrument("form_submission.active_canvas", submission: submission)
      ActiveCanvas.config.on_form_submission&.call(submission)
    rescue => e
      Rails.logger.error("[ActiveCanvas] form submission hook failed: #{e.class}: #{e.message}")
    end
  end
end
