class BackfillActiveCanvasMediaRefs < ActiveRecord::Migration[8.1]
  def up
    ActiveCanvas::MediaRefBackfill.run
  end

  def down
    # No-op: data-ac-media-id attributes are harmless to leave in place.
  end
end
