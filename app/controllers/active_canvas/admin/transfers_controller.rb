require "tempfile"

module ActiveCanvas
  module Admin
    class TransfersController < ApplicationController
      def show
      end

      def export
        options = {
          include_versions: params[:include_versions] == "1",
          include_ai_models: params[:include_ai_models] == "1",
          include_secrets: params[:include_secrets] == "1"
        }
        tempfile = Tempfile.new([ "active_canvas_export", ".zip" ])
        ActiveCanvas::Exporter.new(**options).export_to(tempfile.path)
        send_file tempfile.path,
          type: "application/zip",
          filename: "active_canvas_export_#{Date.current.iso8601}.zip",
          disposition: "attachment"
      end

      def import
        file = params[:file]
        unless file.respond_to?(:tempfile)
          redirect_to admin_transfer_path, alert: "Please choose a .zip file to import." and return
        end
        if file.size > ActiveCanvas::Importer::MAX_ARCHIVE_SIZE
          redirect_to admin_transfer_path, alert: "That file is too large to import." and return
        end
        mode = params[:mode] == "replace" ? :replace : :merge
        summary = ActiveCanvas::Importer.new(file.tempfile.path, mode: mode).run
        notice = "Import complete (#{mode}): #{summary[:created]} created, #{summary[:updated]} updated, #{summary[:skipped]} skipped."
        notice += " Warnings: #{summary[:warnings].join('; ')}" if summary[:warnings].any?
        redirect_to admin_transfer_path, notice: notice
      rescue ActiveCanvas::Importer::InvalidArchive => e
        redirect_to admin_transfer_path, alert: "Import failed: #{e.message}"
      rescue ActiveRecord::RecordInvalid => e
        redirect_to admin_transfer_path, alert: "Import failed: #{e.record.class.name.demodulize} is invalid (#{e.record.errors.full_messages.to_sentence})"
      rescue ActiveRecord::RecordNotUnique => e
        redirect_to admin_transfer_path, alert: "Import failed: a record already exists and could not be imported (#{e.message})"
      rescue ActiveRecord::StatementInvalid => e
        # Covers NotNullViolation and other DB-level rejections (e.g. a legacy
        # manifest row missing a required column) that aren't a Rails-level
        # validation failure but must still flash, not 500.
        redirect_to admin_transfer_path, alert: "Import failed: a database error occurred (#{e.message})"
      ensure
        if file.respond_to?(:tempfile) && file.tempfile
          file.tempfile.close
          file.tempfile.unlink
        end
      end
    end
  end
end
