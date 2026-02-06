class AddSeoFieldsToActiveCanvasPages < ActiveRecord::Migration[8.0]
  COLUMNS = {
    meta_title: :string,
    meta_description: :text,
    og_title: :string,
    og_description: :text,
    og_image: :string,
    canonical_url: :string,
    meta_robots: :string,
    twitter_card: :string,
    twitter_title: :string,
    twitter_description: :text,
    twitter_image: :string,
    structured_data: :text
  }.freeze

  def up
    COLUMNS.each do |name, type|
      add_column :active_canvas_pages, name, type unless column_exists?(:active_canvas_pages, name)
    end
  end

  def down
    COLUMNS.each_key do |name|
      remove_column :active_canvas_pages, name if column_exists?(:active_canvas_pages, name)
    end
  end
end
