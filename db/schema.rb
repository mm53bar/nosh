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

ActiveRecord::Schema[8.1].define(version: 2026_08_09_232254) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
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
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "equipment", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "owned", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_equipment_on_name", unique: true
  end

  create_table "ingredients", force: :cascade do |t|
    t.string "amount"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "recipe_id", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "position"], name: "index_ingredients_on_recipe_id_and_position"
    t.index ["recipe_id"], name: "index_ingredients_on_recipe_id"
  end

  create_table "meal_plan_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "notes"
    t.integer "recipe_id", null: false
    t.integer "servings"
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_meal_plan_entries_on_date"
    t.index ["recipe_id"], name: "index_meal_plan_entries_on_recipe_id"
  end

  create_table "recipe_equipments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "equipment_id", null: false
    t.integer "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_recipe_equipments_on_equipment_id"
    t.index ["recipe_id", "equipment_id"], name: "index_recipe_equipments_on_recipe_id_and_equipment_id", unique: true
    t.index ["recipe_id"], name: "index_recipe_equipments_on_recipe_id"
  end

  create_table "recipe_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "recipe_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "tag_id"], name: "index_recipe_tags_on_recipe_id_and_tag_id", unique: true
    t.index ["recipe_id"], name: "index_recipe_tags_on_recipe_id"
    t.index ["tag_id"], name: "index_recipe_tags_on_tag_id"
  end

  create_table "recipe_techniques", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "recipe_id", null: false
    t.integer "technique_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "technique_id"], name: "index_recipe_techniques_on_recipe_id_and_technique_id", unique: true
    t.index ["recipe_id"], name: "index_recipe_techniques_on_recipe_id"
    t.index ["technique_id"], name: "index_recipe_techniques_on_technique_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cuisine"
    t.text "description"
    t.date "last_made_on"
    t.string "meal_type"
    t.text "notes"
    t.integer "prep_time_minutes"
    t.integer "rating"
    t.integer "servings"
    t.string "source_url"
    t.string "title", null: false
    t.integer "total_time_minutes"
    t.datetime "updated_at", null: false
  end

  create_table "shopping_list_items", force: :cascade do |t|
    t.string "amount"
    t.string "category"
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "instruction", null: false
    t.integer "position", default: 0, null: false
    t.integer "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "position"], name: "index_steps_on_recipe_id_and_position"
    t.index ["recipe_id"], name: "index_steps_on_recipe_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "technique_equipments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "equipment_id", null: false
    t.integer "technique_id", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_technique_equipments_on_equipment_id"
    t.index ["technique_id", "equipment_id"], name: "index_technique_equipments_on_technique_id_and_equipment_id", unique: true
    t.index ["technique_id"], name: "index_technique_equipments_on_technique_id"
  end

  create_table "techniques", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_techniques_on_title", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ingredients", "recipes"
  add_foreign_key "meal_plan_entries", "recipes"
  add_foreign_key "recipe_equipments", "equipment"
  add_foreign_key "recipe_equipments", "recipes"
  add_foreign_key "recipe_tags", "recipes"
  add_foreign_key "recipe_tags", "tags"
  add_foreign_key "recipe_techniques", "recipes"
  add_foreign_key "recipe_techniques", "techniques"
  add_foreign_key "steps", "recipes"
  add_foreign_key "technique_equipments", "equipment"
  add_foreign_key "technique_equipments", "techniques"
end
