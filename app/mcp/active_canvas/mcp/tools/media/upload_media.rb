require "base64"
require "stringio"

module ActiveCanvas
  module Mcp
    module Tools
      module Media
        class UploadMedia < BaseTool
          tool_name "upload_media"
          description "Upload a file from base64-encoded data. content_type is guessed from the filename/bytes when omitted. Rejected if the decoded size exceeds the configured max_upload_size, or if the file type is not allowed (e.g. SVG, unless allow_svg_uploads is enabled). No URL-fetch upload is supported."
          input_schema(
            properties: {
              filename: { type: "string" },
              data_base64: { type: "string" },
              content_type: { type: "string" }
            },
            required: [ "filename", "data_base64" ]
          )
          required_scope :write

          def perform(args)
            filename = args[:filename]
            data_base64 = args[:data_base64]

            fail!("filename is required") if filename.blank?
            fail!("data_base64 is required") if data_base64.blank?

            bytes = decode(data_base64)

            max = ActiveCanvas.config.max_upload_size
            fail!("File is too large (max #{max} bytes)") if bytes.bytesize > max

            content_type = args[:content_type].presence || Marcel::MimeType.for(StringIO.new(bytes), name: filename)

            media = ActiveCanvas::Media.new(filename: filename)
            media.file.attach(io: StringIO.new(bytes), filename: filename, content_type: content_type)
            media.save!

            Serializers.media(media)
          end

          private

          def decode(data_base64)
            Base64.strict_decode64(data_base64)
          rescue ArgumentError
            fail!("data_base64 is not valid base64")
          end
        end
      end
    end
  end
end
