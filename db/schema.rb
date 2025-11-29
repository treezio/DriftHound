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

ActiveRecord::Schema[8.0].define(version: 2025_11_29_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.string "name", null: false
    t.string "token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
  end

  create_table "drift_checks", force: :cascade do |t|
    t.bigint "environment_id", null: false
    t.integer "status"
    t.integer "add_count"
    t.integer "change_count"
    t.integer "destroy_count"
    t.integer "duration"
    t.text "raw_output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "execution_number"
    t.index ["created_at"], name: "index_drift_checks_on_created_at"
    t.index ["environment_id", "execution_number"], name: "index_drift_checks_on_environment_id_and_execution_number", unique: true
    t.index ["environment_id"], name: "index_drift_checks_on_environment_id"
  end

  create_table "environments", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "key", null: false
    t.integer "status", default: 0, null: false
    t.datetime "last_checked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "key"], name: "index_environments_on_project_id_and_key", unique: true
    t.index ["project_id"], name: "index_environments_on_project_id"
    t.index ["status"], name: "index_environments_on_status"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_projects_on_key", unique: true
  end

  add_foreign_key "drift_checks", "environments"
  add_foreign_key "environments", "projects"
end
