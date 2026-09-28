module ActiveCanvas
  module Admin
    class ApiTokensController < ApplicationController
      LEVEL_SCOPES = {
        "read" => %w[read],
        "write" => %w[read write],
        "publish" => %w[read write publish]
      }.freeze

      def create
        scopes = LEVEL_SCOPES[params[:level]]

        unless scopes
          redirect_to admin_settings_path(tab: "api_tokens"), alert: "Unknown access level."
          return
        end

        expires_at, error = parse_expires_at(params[:expires_at])
        if error
          redirect_to admin_settings_path(tab: "api_tokens"), alert: error
          return
        end

        _token, plaintext = ActiveCanvas::ApiToken.issue!(
          name: params[:name],
          scopes: scopes,
          expires_at: expires_at,
          created_by: ActiveCanvas::Current.editor
        )

        redirect_to admin_settings_path(tab: "api_tokens"), flash: { api_token_plaintext: plaintext }
      rescue ActiveRecord::RecordInvalid => e
        redirect_to admin_settings_path(tab: "api_tokens"), alert: e.record.errors.full_messages.to_sentence
      end

      def destroy
        ActiveCanvas::ApiToken.find(params[:id]).revoke!
        redirect_to admin_settings_path(tab: "api_tokens"), notice: "Token revoked."
      end

      private

      # The form's `date_field` posts a date-only string ("2026-10-05"). Passed straight to the
      # `expires_at` datetime column, Rails parses it as that day's midnight, so a token meant to
      # expire "at the end of the day I pick" would already read as expired the moment it's
      # created. Treat it as the end of that day instead, and reject a date already in the past
      # outright (an admin picking a past date almost certainly meant "not that one").
      def parse_expires_at(raw)
        return [ nil, nil ] if raw.blank?

        date = Date.parse(raw)
        return [ nil, "Expiration date can't be in the past." ] if date < Date.current

        [ date.end_of_day, nil ]
      rescue ArgumentError
        [ nil, "Invalid expiration date." ]
      end
    end
  end
end
