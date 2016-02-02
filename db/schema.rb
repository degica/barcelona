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

ActiveRecord::Schema.define(version: 20160202021528) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "districts", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "s3_bucket_name"
    t.text     "dockercfg"
    t.text     "encrypted_aws_access_key_id"
    t.text     "encrypted_aws_secret_access_key"
    t.string   "cidr_block"
    t.string   "bastion_key_pair"
    t.string   "stack_name"
    t.string   "nat_type"
    t.string   "cluster_backend"
    t.integer  "cluster_size"
    t.string   "cluster_instance_type"
  end

  create_table "env_vars", force: :cascade do |t|
    t.integer "heritage_id"
    t.string  "key"
    t.text    "encrypted_value"
  end

  add_index "env_vars", ["heritage_id", "key"], name: "index_env_vars_on_heritage_id_and_key", unique: true, using: :btree
  add_index "env_vars", ["heritage_id"], name: "index_env_vars_on_heritage_id", using: :btree

  create_table "events", force: :cascade do |t|
    t.string   "uuid"
    t.integer  "heritage_id"
    t.text     "message"
    t.string   "level"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "events", ["heritage_id"], name: "index_events_on_heritage_id", using: :btree
  add_index "events", ["uuid"], name: "index_events_on_uuid", unique: true, using: :btree

  create_table "heritages", force: :cascade do |t|
    t.string   "name",          null: false
    t.string   "image_name"
    t.string   "image_tag"
    t.integer  "district_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.text     "before_deploy"
    t.text     "slack_url"
    t.string   "token"
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

  create_table "plugins", force: :cascade do |t|
    t.text     "plugin_attributes"
    t.integer  "district_id"
    t.string   "name"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "plugins", ["district_id"], name: "index_plugins_on_district_id", using: :btree

  create_table "port_mappings", force: :cascade do |t|
    t.integer  "host_port"
    t.integer  "lb_port"
    t.integer  "container_port"
    t.integer  "service_id"
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.string   "protocol"
    t.boolean  "enable_proxy_protocol", default: false
  end

  add_index "port_mappings", ["service_id"], name: "index_port_mappings_on_service_id", using: :btree

  create_table "services", force: :cascade do |t|
    t.string   "name",                                    null: false
    t.integer  "cpu"
    t.integer  "memory"
    t.text     "command"
    t.boolean  "public"
    t.integer  "heritage_id"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.string   "reverse_proxy_image"
    t.text     "hosts"
    t.string   "service_type",        default: "default"
    t.boolean  "force_ssl"
  end

  add_index "services", ["heritage_id"], name: "index_services_on_heritage_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.string   "token_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text     "public_key"
    t.text     "roles"
  end

  add_index "users", ["name"], name: "index_users_on_name", unique: true, using: :btree
  add_index "users", ["token_hash"], name: "index_users_on_token_hash", unique: true, using: :btree

  create_table "users_districts", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "district_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "users_districts", ["district_id"], name: "index_users_districts_on_district_id", using: :btree
  add_index "users_districts", ["user_id"], name: "index_users_districts_on_user_id", using: :btree

  add_foreign_key "env_vars", "heritages"
  add_foreign_key "events", "heritages"
  add_foreign_key "heritages", "districts"
  add_foreign_key "oneoffs", "heritages"
  add_foreign_key "plugins", "districts"
  add_foreign_key "port_mappings", "services"
  add_foreign_key "services", "heritages"
  add_foreign_key "users_districts", "districts"
  add_foreign_key "users_districts", "users"
end
