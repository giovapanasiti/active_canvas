require "test_helper"

class ActiveCanvas::Mcp::MediaToolsTest < ActionDispatch::IntegrationTest
  # 1x1 transparent PNG.
  TINY_PNG_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

  setup { @token = mcp_token(%w[read write publish]) }

  test "upload_media succeeds and returns an html_snippet carrying the media id" do
    created, err = mcp_call(@token, "upload_media", { filename: "pixel.png", data_base64: TINY_PNG_BASE64 })
    assert_nil err
    assert_equal "pixel.png", created["name"]
    assert_equal "image/png", created["content_type"]
    assert_match(/data-ac-media-id="#{created["id"]}"/, created["html_snippet"])
    assert ActiveCanvas::Media.exists?(created["id"])
  end

  test "media responses include url and filename alongside src and name" do
    created, err = mcp_call(@token, "upload_media", { filename: "pixel.png", data_base64: TINY_PNG_BASE64 })
    assert_nil err
    assert_equal created["src"], created["url"]
    assert_equal created["name"], created["filename"]

    got, err = mcp_call(@token, "get_media", { id: created["id"] })
    assert_nil err
    assert_equal got["src"], got["url"]
    assert_equal got["name"], got["filename"]
  end

  test "upload_media rejects invalid base64" do
    _, err = mcp_call(@token, "upload_media", { filename: "x.png", data_base64: "not-valid-base64!!!" })
    refute_nil err
    assert_match(/not valid base64/i, err)
  end

  test "upload_media rejects a file larger than max_upload_size" do
    with_config(max_upload_size: 10) do
      _, err = mcp_call(@token, "upload_media", { filename: "pixel.png", data_base64: TINY_PNG_BASE64 })
      refute_nil err
      assert_match(/too large/i, err)
      assert_match(/10/, err)
    end
  end

  test "upload_media rejects svg uploads when allow_svg_uploads is false" do
    with_config(allow_svg_uploads: false) do
      svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
      _, err = mcp_call(@token, "upload_media", {
        filename: "icon.svg",
        data_base64: Base64.strict_encode64(svg),
        content_type: "image/svg+xml"
      })
      refute_nil err
      assert_match(/svg/i, err)
    end
  end

  test "delete_media removes the record" do
    media = build_saved_media
    deleted, err = mcp_call(@token, "delete_media", { id: media.id })
    assert_nil err
    assert_equal true, deleted["deleted"]
    assert_equal media.id, deleted["id"]
    assert_not ActiveCanvas::Media.exists?(media.id)
  end

  test "list_media defaults to images_only and paginates" do
    3.times { |i| build_saved_media(filename: "img#{i}.png") }

    other = ActiveCanvas::Media.new(filename: "note.txt", content_type: "text/plain", byte_size: 2)
    other.file.attach(io: StringIO.new("hi"), filename: "note.txt", content_type: "text/plain")
    other.save!(validate: false)

    limited, err = mcp_call(@token, "list_media", { limit: 2 })
    assert_nil err
    assert_equal 2, limited["items"].length
    assert_equal 3, limited["total"]
    assert_not_includes limited["items"].map { |i| i["name"] }, "note.txt"

    all_listed, err = mcp_call(@token, "list_media", { images_only: false })
    assert_nil err
    assert_includes all_listed["items"].map { |i| i["name"] }, "note.txt"
  end

  test "get_media returns the record with metadata" do
    media = build_saved_media
    got, err = mcp_call(@token, "get_media", { id: media.id })
    assert_nil err
    assert_equal media.id, got["id"]
    assert got.key?("metadata")
  end
end
