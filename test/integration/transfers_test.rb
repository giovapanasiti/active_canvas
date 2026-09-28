require "test_helper"
require "zip"

class TransfersTest < ActionDispatch::IntegrationTest
  setup do
    @pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
    ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: @pt, content: "<p>hi</p>")
  end

  test "export returns a zip download" do
    get "/canvas/admin/transfer/export", params: { include_versions: "1", include_ai_models: "1" }
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert response.body.bytesize.positive?
  end

  test "import applies an uploaded zip and redirects with a summary" do
    path = File.join(Dir.tmpdir, "ac_ctrl_#{rand(1_000_000)}.zip")
    ActiveCanvas::Exporter.new.export_to(path)

    ActiveCanvas::Page.find_by(slug: "home").update!(title: "Changed")

    upload = Rack::Test::UploadedFile.new(path, "application/zip")
    post "/canvas/admin/transfer/import", params: { file: upload, mode: "merge" }

    assert_response :redirect
    follow_redirect!
    assert_equal "Home", ActiveCanvas::Page.find_by(slug: "home").title
  end

  test "import without a file redirects with an alert" do
    post "/canvas/admin/transfer/import", params: { mode: "merge" }
    assert_response :redirect
  end

  test "transfer page renders with export and import forms" do
    get "/canvas/admin/transfer"
    assert_response :success
    assert_includes response.body, "Export"
    assert_includes response.body, "Import"
    assert_includes response.body, "include_secrets"
    assert_includes response.body, "/canvas/admin/transfer/import"
  end

  test "uploading a non-zip file redirects with an alert instead of raising" do
    path = File.join(Dir.tmpdir, "ac_ctrl_not_a_zip_#{rand(1_000_000)}.txt")
    File.write(path, "this is not a zip file")

    upload = Rack::Test::UploadedFile.new(path, "application/zip")
    post "/canvas/admin/transfer/import", params: { file: upload, mode: "replace" }

    assert_response :redirect
    follow_redirect!
    assert_match(/import failed/i, flash[:alert].to_s)
  end

  test "an invalid record in the manifest redirects with a named alert and leaves the database unchanged" do
    path = File.join(Dir.tmpdir, "ac_ctrl_invalid_#{rand(1_000_000)}.zip")
    ActiveCanvas::Exporter.new.export_to(path)
    Zip::File.open(path) do |z|
      manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
      manifest["pages"].first["title"] = "" # blank title fails Page's presence validation
      z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
    end
    pages_before = ActiveCanvas::Page.count

    upload = Rack::Test::UploadedFile.new(path, "application/zip")
    post "/canvas/admin/transfer/import", params: { file: upload, mode: "replace" }

    assert_response :redirect
    follow_redirect!
    assert_match(/import failed/i, flash[:alert].to_s)
    assert_match(/page/i, flash[:alert].to_s)
    assert_equal pages_before, ActiveCanvas::Page.count, "the failed import must not leave any partial writes"
  end
end
