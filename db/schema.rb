# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150930044803) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "districts", force: :cascade do |t|
    t.string   "name"
    t.string   "vpc_id"
    t.string   "public_elb_security_group"
    t.string   "private_elb_security_group"
    t.string   "instance_security_group"
    t.string   "ecs_service_role"
    t.string   "ecs_instance_role"
    t.string   "docker_registry_url"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "private_hosted_zone_id"
    t.string   "s3_bucket_name"
  end

  create_table "env_vars", force: :cascade do |t|
    t.integer "heritage_id"
    t.string  "key"
    t.text    "encrypted_value"
  end

  add_index "env_vars", ["heritage_id", "key"], name: "index_env_vars_on_heritage_id_and_key", unique: true, using: :btree
  add_index "env_vars", ["heritage_id"], name: "index_env_vars_on_heritage_id", using: :btree

  create_table "heritages", force: :cascade do |t|
    t.string   "name",           null: false
    t.string   "container_name"
    t.string   "container_tag"
    t.integer  "district_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "heritages", ["district_id"], name: "index_heritages_on_district_id", using: :btree
  add_index "heritages", ["name"], name: "index_heritages_on_name", unique: true, using: :btree

  create_table "oneoffs", force: :cascade do |t|
    t.string   "task_arn"
    t.integer  "heritage_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.text     "command"
  end

  add_index "oneoffs", ["heritage_id"], name: "index_oneoffs_on_heritage_id", using: :btree

  create_table "port_mappings", force: :cascade do |t|
    t.integer  "host_port"
    t.integer  "lb_port"
    t.integer  "container_port"
    t.integer  "service_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "port_mappings", ["host_port"], name: "index_port_mappings_on_host_port", unique: true, using: :btree
  add_index "port_mappings", ["service_id"], name: "index_port_mappings_on_service_id", using: :btree

  create_table "services", force: :cascade do |t|
    t.string   "name",        null: false
    t.integer  "cpu"
    t.integer  "memory"
    t.string   "command"
    t.boolean  "public"
    t.integer  "heritage_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "services", ["heritage_id"], name: "index_services_on_heritage_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.string   "token_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "users", ["name"], name: "index_users_on_name", unique: true, using: :btree
  add_index "users", ["token_hash"], name: "index_users_on_token_hash", unique: true, using: :btree

  add_foreign_key "env_vars", "heritages"
  add_foreign_key "heritages", "districts"
  add_foreign_key "oneoffs", "heritages"
  add_foreign_key "port_mappings", "services"
  add_foreign_key "services", "heritages"
end
