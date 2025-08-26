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

ActiveRecord::Schema[7.1].define(version: 2025_08_26_203237) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "scores", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "title"
    t.integer "status", default: 0, null: false
    t.string "imported_format"
    t.string "key_sig"
    t.string "time_sig"
    t.integer "tempo"
    t.jsonb "doc"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tracks_count", default: 0, null: false
    t.index ["project_id", "title"], name: "index_scores_on_project_id_and_title", unique: true
    t.index ["project_id"], name: "index_scores_on_project_id"
    t.index ["status"], name: "index_scores_on_status"
    t.index ["tracks_count"], name: "index_scores_on_tracks_count"
  end

  create_table "tracks", force: :cascade do |t|
    t.bigint "score_id", null: false
    t.string "name"
    t.string "instrument"
    t.string "tuning"
    t.integer "capo"
    t.integer "midi_channel"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["midi_channel"], name: "index_tracks_on_midi_channel"
    t.index ["score_id", "midi_channel"], name: "index_tracks_on_score_id_and_midi_channel_unique", unique: true, where: "(midi_channel IS NOT NULL)"
    t.index ["score_id", "name"], name: "index_tracks_on_score_id_and_name", unique: true
    t.index ["score_id"], name: "index_tracks_on_score_id"
    t.check_constraint "midi_channel IS NULL OR midi_channel >= 1 AND midi_channel <= 16", name: "midi_channel_range_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "projects", "users"
  add_foreign_key "scores", "projects"
  add_foreign_key "tracks", "scores"
end
