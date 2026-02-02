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

ActiveRecord::Schema[8.1].define(version: 2026_02_02_000007) do
  create_table "active_canvas_media", force: :cascade do |t|
    t.integer "byte_size"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.text "metadata"
    t.datetime "updated_at", null: false
    t.index ["content_type"], name: "index_active_canvas_media_on_content_type"
    t.index ["created_at"], name: "index_active_canvas_media_on_created_at"
  end

  create_table "active_canvas_page_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_active_canvas_page_types_on_key", unique: true
  end

  create_table "active_canvas_pages", force: :cascade do |t|
    t.string "canonical_url"
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
    t.string "slug"
    t.text "structured_data"
    t.string "title", null: false
    t.string "twitter_card"
    t.text "twitter_description"
    t.string "twitter_image"
    t.string "twitter_title"
    t.datetime "updated_at", null: false
    t.index ["page_type_id"], name: "index_active_canvas_pages_on_page_type_id"
    t.index ["slug"], name: "index_active_canvas_pages_on_slug", unique: true
  end

  create_table "active_canvas_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_active_canvas_settings_on_key", unique: true
  end

  add_foreign_key "active_canvas_pages", "active_canvas_page_types", column: "page_type_id"
end
