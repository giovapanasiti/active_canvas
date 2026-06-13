require "stringio"

module ActiveCanvasTestHelpers
  # Build and persist a Media with an attached fake file.
  def build_saved_media(filename: "sample.png", content_type: "image/png")
    media = ActiveCanvas::Media.new(filename: filename)
    media.file.attach(
      io: StringIO.new("fake-bytes-#{filename}"),
      filename: filename,
      content_type: content_type
    )
    media.save!
    media
  end

  # Temporarily override ActiveCanvas.config attributes, restoring afterwards.
  def with_config(**overrides)
    config = ActiveCanvas.config
    previous = overrides.keys.index_with { |k| config.public_send(k) }
    overrides.each { |k, v| config.public_send("#{k}=", v) }
    yield
  ensure
    previous.each { |k, v| config.public_send("#{k}=", v) }
  end

  # Capture Rails.logger output produced inside the block.
  def capture_log
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end

  def default_page_type
    ActiveCanvas::PageType.find_or_create_by!(key: "default") { |pt| pt.name = "Default" }
  end

  def create_page(content:, title: "Test Page")
    ActiveCanvas::Page.create!(title: title, page_type: default_page_type, content: content)
  end
end
