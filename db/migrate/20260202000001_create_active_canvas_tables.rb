class CreateActiveCanvasTables < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_page_types, if_not_exists: true do |t|
      t.string :name, null: false
      t.string :key, null: false

      t.timestamps
    end

    add_index :active_canvas_page_types, :key, unique: true, if_not_exists: true

    create_table :active_canvas_pages, if_not_exists: true do |t|
      t.string :title, null: false
      t.string :slug
      t.text :content
      t.references :page_type, null: false, foreign_key: { to_table: :active_canvas_page_types }
      t.boolean :published, default: false, null: false

      # Editor data
      t.text :content_css
      t.text :content_js
      t.text :content_components

      # Tailwind compilation
      t.text :compiled_tailwind_css
      t.datetime :tailwind_compiled_at

      # Header/Footer
      t.boolean :show_header, default: true, null: false
      t.boolean :show_footer, default: true, null: false

      # SEO
      t.string :meta_title
      t.text :meta_description
      t.string :canonical_url
      t.string :meta_robots

      # Open Graph
      t.string :og_title
      t.text :og_description
      t.string :og_image

      # Twitter
      t.string :twitter_card
      t.string :twitter_title
      t.text :twitter_description
      t.string :twitter_image

      # Structured data
      t.text :structured_data

      t.timestamps
    end

    add_index :active_canvas_pages, :slug, unique: true, if_not_exists: true

    create_table :active_canvas_page_versions, if_not_exists: true do |t|
      t.references :page, null: false, foreign_key: { to_table: :active_canvas_pages }
      t.integer :version_number, null: false
      t.text :content_before
      t.text :content_after
      t.text :content_diff
      t.text :css_before
      t.text :css_after
      t.string :change_summary
      t.string :changed_by
      t.integer :content_size_before
      t.integer :content_size_after

      t.timestamps
    end

    add_index :active_canvas_page_versions, [:page_id, :version_number], unique: true, if_not_exists: true
    add_index :active_canvas_page_versions, :created_at, if_not_exists: true

    create_table :active_canvas_partials, if_not_exists: true do |t|
      t.string :name, null: false
      t.string :partial_type, null: false
      t.text :content
      t.text :content_css
      t.text :content_js
      t.text :content_components
      t.text :compiled_css
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :active_canvas_partials, :partial_type, unique: true, if_not_exists: true

    create_table :active_canvas_media, if_not_exists: true do |t|
      t.string :filename, null: false
      t.string :content_type
      t.integer :byte_size
      t.text :metadata

      t.timestamps
    end

    add_index :active_canvas_media, :content_type, if_not_exists: true
    add_index :active_canvas_media, :created_at, if_not_exists: true

    create_table :active_canvas_settings, if_not_exists: true do |t|
      t.string :key, null: false
      t.text :value
      t.text :encrypted_value

      t.timestamps
    end

    add_index :active_canvas_settings, :key, unique: true, if_not_exists: true
  end
end
