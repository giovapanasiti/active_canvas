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

ActiveRecord::Schema[8.1].define(version: 2026_09_28_000002) do
  create_table "active_canvas_ai_models", force: :cascade do |t|
    t.boolean "active", default: true
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.text "input_modalities"
    t.decimal "input_price_per_million", precision: 10, scale: 4
    t.integer "max_tokens"
    t.string "model_id", null: false
    t.string "model_type"
    t.string "name"
    t.text "output_modalities"
    t.decimal "output_price_per_million", precision: 10, scale: 4
    t.string "provider", null: false
    t.boolean "supports_functions", default: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_active_canvas_ai_models_on_active"
    t.index ["model_id"], name: "index_active_canvas_ai_models_on_model_id", unique: true
    t.index ["model_type"], name: "index_active_canvas_ai_models_on_model_type"
    t.index ["provider"], name: "index_active_canvas_ai_models_on_provider"
  end

  create_table "active_canvas_api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "created_by"
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.json "scopes", default: ["read"], null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_active_canvas_api_tokens_on_token_digest", unique: true
  end

  create_table "active_canvas_collection_item_versions", force: :cascade do |t|
    t.string "change_summary"
    t.string "changed_by"
    t.integer "collection_item_id", null: false
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.index ["collection_item_id", "version_number"], name: "idx_ac_collection_item_versions_on_item_and_number", unique: true
  end

  create_table "active_canvas_collection_items", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.json "draft_data", default: {}, null: false
    t.datetime "published_at"
    t.string "slug"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "slug"], name: "index_ac_collection_items_on_collection_id_and_slug", unique: true, where: "slug IS NOT NULL"
    t.index ["collection_id", "status"], name: "idx_on_collection_id_status_ce43821072"
  end

  create_table "active_canvas_collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description_field"
    t.json "fields", default: [], null: false
    t.boolean "has_pages", default: false, null: false
    t.string "image_field"
    t.string "name", null: false
    t.integer "per_page", default: 12, null: false
    t.boolean "show_in_sidebar", default: false, null: false
    t.string "slug", null: false
    t.string "title_field"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_active_canvas_collections_on_slug", unique: true
  end

  create_table "active_canvas_form_submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.string "form_key", null: false
    t.string "ip"
    t.integer "page_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["page_id", "form_key"], name: "index_active_canvas_form_submissions_on_page_id_and_form_key"
  end

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

  create_table "active_canvas_page_redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "from_slug", null: false
    t.integer "page_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_slug"], name: "index_active_canvas_page_redirects_on_from_slug", unique: true
    t.index ["page_id"], name: "index_active_canvas_page_redirects_on_page_id"
  end

  create_table "active_canvas_page_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_active_canvas_page_types_on_key", unique: true
  end

  create_table "active_canvas_page_versions", force: :cascade do |t|
    t.json "bindings_after"
    t.json "bindings_before"
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
    t.index ["created_at"], name: "index_active_canvas_page_versions_on_created_at"
    t.index ["page_id", "version_number"], name: "idx_on_page_id_version_number_e0425bcf98", unique: true
    t.index ["page_id"], name: "index_active_canvas_page_versions_on_page_id"
  end

  create_table "active_canvas_pages", force: :cascade do |t|
    t.json "bindings", default: {}, null: false
    t.string "canonical_url"
    t.integer "collection_id"
    t.string "collection_role"
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
    t.boolean "template_enabled", default: false, null: false
    t.string "title", null: false
    t.string "twitter_card"
    t.text "twitter_description"
    t.string "twitter_image"
    t.string "twitter_title"
    t.datetime "updated_at", null: false
    t.index ["collection_id", "collection_role"], name: "index_active_canvas_pages_on_collection_id_and_role", unique: true
    t.index ["collection_id"], name: "index_active_canvas_pages_on_collection_id"
    t.index ["page_type_id"], name: "index_active_canvas_pages_on_page_type_id"
    t.index ["slug"], name: "index_active_canvas_pages_on_slug", unique: true
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
    t.index ["partial_type"], name: "index_active_canvas_partials_on_partial_type", unique: true
  end

  create_table "active_canvas_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_value"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_active_canvas_settings_on_key", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "excerpt"
    t.boolean "published", default: false
    t.datetime "published_at"
    t.string "slug"
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_canvas_collection_item_versions", "active_canvas_collection_items", column: "collection_item_id"
  add_foreign_key "active_canvas_collection_items", "active_canvas_collections", column: "collection_id"
  add_foreign_key "active_canvas_form_submissions", "active_canvas_pages", column: "page_id"
  add_foreign_key "active_canvas_page_redirects", "active_canvas_pages", column: "page_id"
  add_foreign_key "active_canvas_page_versions", "active_canvas_pages", column: "page_id"
  add_foreign_key "active_canvas_pages", "active_canvas_collections", column: "collection_id"
  add_foreign_key "active_canvas_pages", "active_canvas_page_types", column: "page_type_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
