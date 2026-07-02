module ActiveCanvas
  # Arms authored <form> elements at render time: points them at the engine's
  # public endpoint, injects the signed anti-spam token and honeypot, and
  # drives the no-JS success/error feedback via query params. Idempotent:
  # engine-injected nodes are replaced, never duplicated.
  class FormStamper
    HONEYPOT_FIELD = "ac_website".freeze
    TOKEN_FIELD = "ac_token".freeze
    TOKEN_EXPIRY = 1.week

    ERROR_MESSAGES = {
      "missing_fields" => "Please fill in all required fields.",
      "too_fast" => "That was too quick — please try again.",
      "invalid" => "Something went wrong. Please try again."
    }.freeze

    def self.verifier
      Rails.application.message_verifier("active_canvas/forms")
    end

    def self.token_for(page:, form_key:, issued_at: Time.current)
      verifier.generate(
        { "page_id" => page.id, "form_key" => form_key, "issued_at" => issued_at.to_f },
        expires_in: TOKEN_EXPIRY
      )
    end

    # action: the mounted submissions path from the request context
    # (engine route helpers outside a request don't know the mount point).
    def initialize(html, page:, feedback: nil, action: nil)
      @html = html.to_s
      @page = page
      @feedback = feedback || {}
      @action = action || Engine.routes.url_helpers.public_form_submissions_path
    end

    def stamp
      return @html unless @html.include?("<form")

      doc = Nokogiri::HTML5.fragment(@html)
      doc.css("form").each_with_index do |form, index|
        arm(form, FormSchema.key_for(form, index))
      end
      doc.to_html
    end

    private

    def arm(form, form_key)
      form["action"] = @action
      form["method"] = "post"

      form.css("input[name^='ac_']").each(&:remove)
      form.add_child(hidden_input(TOKEN_FIELD, self.class.token_for(page: @page, form_key: form_key)))
      form.add_child(honeypot_input)

      ensure_feedback_element(form, "data-ac-success", "Thank you!")
      ensure_feedback_element(form, "data-ac-error", ERROR_MESSAGES["invalid"])
      apply_feedback(form, form_key)
    end

    def hidden_input(name, value)
      %(<input type="hidden" name="#{name}" value="#{CGI.escapeHTML(value)}">)
    end

    def honeypot_input
      %(<input type="text" name="#{HONEYPOT_FIELD}" value="" style="position:absolute;left:-9999px" tabindex="-1" autocomplete="off">)
    end

    def ensure_feedback_element(form, attribute, default_text)
      element = form.at_css("[#{attribute}]")
      element ||= form.add_child(%(<div #{attribute}>#{default_text}</div>)).first
      element["hidden"] = ""
    end

    def apply_feedback(form, form_key)
      if @feedback[:submitted] == form_key
        form.at_css("[data-ac-success]").remove_attribute("hidden")
      elsif @feedback[:error].present? && @feedback[:form_key] == form_key
        error = form.at_css("[data-ac-error]")
        error.content = ERROR_MESSAGES.fetch(@feedback[:error], ERROR_MESSAGES["invalid"])
        error.remove_attribute("hidden")
      end
    end
  end
end
