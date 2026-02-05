# This migration comes from active_canvas (originally 20260202000007)
class AddSeoFieldsToActiveCanvasPages < ActiveRecord::Migration[8.0]
  def change
    # Recommended SEO fields
    add_column :active_canvas_pages, :meta_title, :string
    add_column :active_canvas_pages, :meta_description, :text
    add_column :active_canvas_pages, :og_title, :string
    add_column :active_canvas_pages, :og_description, :text
    add_column :active_canvas_pages, :og_image, :string

    # Optional SEO fields
    add_column :active_canvas_pages, :canonical_url, :string
    add_column :active_canvas_pages, :meta_robots, :string
    add_column :active_canvas_pages, :twitter_card, :string
    add_column :active_canvas_pages, :twitter_title, :string
    add_column :active_canvas_pages, :twitter_description, :text
    add_column :active_canvas_pages, :twitter_image, :string
    add_column :active_canvas_pages, :structured_data, :text
  end
end
