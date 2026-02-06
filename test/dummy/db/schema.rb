# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_06_083551) do
  create_table "active_canvas_ai_models", force: :cascade do |t|
    t.boolean "active", default: true
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.decimal "input_price_per_million", precision: 10, scale: 4
    t.integer "max_tokens"
    t.string "model_id", null: false
    t.string "model_type"
    t.string "name"
    t.decimal "output_price_per_million", precision: 10, scale: 4
    t.string "provider", null: false
    t.boolean "supports_functions", default: false
    t.boolean "supports_vision", default: false
    t.datetime "updated_at", null: false
    t.index [ "active" ], name: "index_active_canvas_ai_models_on_active"
    t.index [ "model_id" ], name: "index_active_canvas_ai_models_on_model_id", unique: true
    t.index [ "model_type" ], name: "index_active_canvas_ai_models_on_model_type"
    t.index [ "provider" ], name: "index_active_canvas_ai_models_on_provider"
  end

  create_table "active_canvas_media", force: :cascade do |t|
    t.integer "byte_size"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.text "metadata"
    t.datetime "updated_at", null: false
    t.index [ "content_type" ], name: "index_active_canvas_media_on_content_type"
    t.index [ "created_at" ], name: "index_active_canvas_media_on_created_at"
  end

  create_table "active_canvas_page_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "key" ], name: "index_active_canvas_page_types_on_key", unique: true
  end

  create_table "active_canvas_page_versions", force: :cascade do |t|
    t.string "change_summary"
    t.string "changed_by"
    t.text "content_after"
    t.text "content_before"
    t.text "content_diff"
    t.integer "content_size_after"
    t.integer "content_size_before"
    t.datetime "created_at", null: false
    t.text "css_after"
    t.text "css_before"
    t.integer "page_id", null: false
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.index [ "created_at" ], name: "index_active_canvas_page_versions_on_created_at"
    t.index [ "page_id", "version_number" ], name: "idx_on_page_id_version_number_e0425bcf98", unique: true
    t.index [ "page_id" ], name: "index_active_canvas_page_versions_on_page_id"
  end

  create_table "active_canvas_pages", force: :cascade do |t|
    t.string "canonical_url"
    t.text "compiled_tailwind_css"
    t.text "content"
    t.text "content_components"
    t.text "content_css"
    t.text "content_js"
    t.datetime "created_at", null: false
    t.text "meta_description"
    t.string "meta_robots"
    t.string "meta_title"
    t.text "og_description"
    t.string "og_image"
    t.string "og_title"
    t.integer "page_type_id", null: false
    t.boolean "published", default: false, null: false
    t.boolean "show_footer", default: true, null: false
    t.boolean "show_header", default: true, null: false
    t.string "slug"
    t.text "structured_data"
    t.datetime "tailwind_compiled_at"
    t.string "title", null: false
    t.string "twitter_card"
    t.text "twitter_description"
    t.string "twitter_image"
    t.string "twitter_title"
    t.datetime "updated_at", null: false
    t.index [ "page_type_id" ], name: "index_active_canvas_pages_on_page_type_id"
    t.index [ "slug" ], name: "index_active_canvas_pages_on_slug", unique: true
  end

  create_table "active_canvas_partials", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "compiled_css"
    t.text "content"
    t.text "content_components"
    t.text "content_css"
    t.text "content_js"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "partial_type", null: false
    t.datetime "updated_at", null: false
    t.index [ "partial_type" ], name: "index_active_canvas_partials_on_partial_type", unique: true
  end

  create_table "active_canvas_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_value"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index [ "key" ], name: "index_active_canvas_settings_on_key", unique: true
  end

  add_foreign_key "active_canvas_page_versions", "active_canvas_pages", column: "page_id"
  add_foreign_key "active_canvas_pages", "active_canvas_page_types", column: "page_type_id"
end
