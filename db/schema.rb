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

ActiveRecord::Schema[8.0].define(version: 2026_02_25_120000) do
  create_table "import_runs", force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.integer "total_files", default: 0
    t.integer "completed_files", default: 0
    t.integer "total_records_imported", default: 0
    t.string "current_file"
    t.text "error_message"
    t.json "completed_filenames", default: []
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
