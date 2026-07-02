# This migration comes from active_canvas (originally 20260613000002)
class BackfillActiveCanvasMediaRefs < ActiveRecord::Migration[8.1]
  def up
    ActiveCanvas::MediaRefBackfill.run
  end

  def down
    # No-op: data-ac-media-id attributes are harmless to leave in place.
  end
end
