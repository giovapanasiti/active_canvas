require "test_helper"

module ActiveCanvas
  class ContentRendererTest < ActiveSupport::TestCase
    test "rewrites img src for a known media id to a fresh url" do
      media = build_saved_media
      html = %(<img data-ac-media-id="#{media.id}" src="/stale.png" alt="x">)

      freeze_time do
        out = ActiveCanvas::ContentRenderer.resolve(html)
        assert_includes out, media.url
        refute_includes out, "/stale.png"
        assert_includes out, %(data-ac-media-id="#{media.id}")
      end
    end

    test "leaves images without data-ac-media-id untouched" do
      html = %(<img src="/plain.png">)
      assert_includes ActiveCanvas::ContentRenderer.resolve(html), "/plain.png"
    end

    test "leaves a node whose media id no longer exists in place" do
      html = %(<img data-ac-media-id="999999" src="/orig.png">)
      assert_includes ActiveCanvas::ContentRenderer.resolve(html), "/orig.png"
    end

    test "returns blank content unchanged" do
      assert_equal "", ActiveCanvas::ContentRenderer.resolve("")
      assert_nil ActiveCanvas::ContentRenderer.resolve(nil)
    end

    test "leaves src untouched when the media has no attached file (orphaned row)" do
      media = build_saved_media
      media.file.purge
      html = %(<img data-ac-media-id="#{media.id}" src="/orig.png">)

      out = ActiveCanvas::ContentRenderer.resolve(html)
      assert_includes out, "/orig.png"
    end

    test "batch-loads referenced media in a single media query" do
      m1 = build_saved_media
      m2 = build_saved_media(filename: "two.png")
      html = %(<img data-ac-media-id="#{m1.id}"><img data-ac-media-id="#{m2.id}">)

      assert_media_table_query_count(1) { ActiveCanvas::ContentRenderer.resolve(html) }
    end

    private

    def assert_media_table_query_count(expected, &block)
      queries = []
      callback = ->(_n, _s, _f, _id, payload) do
        sql = payload[:sql]
        next if payload[:name] == "SCHEMA"
        queries << sql if sql =~ /SELECT.+FROM\s+["`]?active_canvas_media["`]?/i
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
      assert_equal expected, queries.size,
        "expected #{expected} active_canvas_media query/queries, got #{queries.size}:\n#{queries.join("\n")}"
    end
  end
end
