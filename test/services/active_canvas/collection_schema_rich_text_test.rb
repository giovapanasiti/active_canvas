require "test_helper"

module ActiveCanvas
  class CollectionSchemaRichTextTest < ActiveSupport::TestCase
    FIELDS = [ { "id" => "body", "type" => "rich_text" } ].freeze

    def schema
      ActiveCanvas::CollectionSchema.new(FIELDS)
    end

    def attach_image(filename: "pic.png")
      media = ActiveCanvas::Media.new
      media.file.attach(io: StringIO.new("x"), filename: filename, content_type: "image/png")
      media.save!
      media
    end

    test "coerce_for_storage keeps action-text-attachment tags and basic formatting" do
      media = attach_image
      sgid = media.file.blob.attachable_sgid
      html = %(<p><strong>Hi</strong> there</p><action-text-attachment sgid="#{sgid}" content-type="image/png" filename="pic.png" width="1" height="1"></action-text-attachment>)

      out = schema.coerce_for_storage("body", html)

      assert_includes out, "<strong>Hi</strong>"
      assert_includes out, "<action-text-attachment"
      assert_includes out, %(sgid="#{sgid}")
    end

    test "coerce_for_storage strips script tags and event-handler attributes" do
      out = schema.coerce_for_storage("body", %(<p onclick="alert(1)" onerror="alert(1)">hi</p><script>alert(1)</script>))

      refute_includes out, "<script"
      refute_includes out, "onclick"
      refute_includes out, "onerror"
      assert_includes out, "hi"
    end

    test "coerce_for_storage keeps our own data-ac-media-id media references" do
      media = attach_image
      out = schema.coerce_for_storage("body", %(<img data-ac-media-id="#{media.id}">))

      assert_includes out, %(data-ac-media-id="#{media.id}")
    end

    test "coerce_for_storage blanks out a nil or empty value" do
      assert_equal "", schema.coerce_for_storage("body", nil)
      assert_equal "", schema.coerce_for_storage("body", "")
    end

    test "coerce_for_liquid renders a real blob attachment to its attachment markup outside a request" do
      media = attach_image
      sgid = media.file.blob.attachable_sgid
      stored = schema.coerce_for_storage("body",
        %(<action-text-attachment sgid="#{sgid}" content-type="image/png" filename="pic.png" width="1" height="1"></action-text-attachment>))

      out = schema.coerce_for_liquid("body", stored)

      assert out.html_safe?, "rendered rich text must be marked html_safe"
      assert_includes out, "attachment"
      assert_includes out, "pic.png"
    end

    test "coerce_for_liquid renders plain formatting and marks it safe" do
      out = schema.coerce_for_liquid("body", "<p><b>x</b></p>")

      assert out.html_safe?
      assert_includes out, "<b>x</b>"
    end

    test "coerce_for_liquid returns an empty safe string for a blank value" do
      out = schema.coerce_for_liquid("body", nil)

      assert_equal "", out
      assert out.html_safe?
    end
  end
end
