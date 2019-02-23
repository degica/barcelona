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

ActiveRecord::Schema.define(version: 2019_02_23_124754) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "districts", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "s3_bucket_name"
    t.text "dockercfg"
    t.text "encrypted_aws_secret_access_key"
    t.string "cidr_block"
    t.string "bastion_key_pair"
    t.string "stack_name"
    t.string "nat_type"
    t.string "cluster_backend"
    t.integer "cluster_size"
    t.string "cluster_instance_type"
    t.string "aws_access_key_id"
    t.string "region"
    t.text "ssh_ca_public_key"
    t.string "aws_role"
  end

  create_table "endpoints", force: :cascade do |t|
    t.integer "district_id"
    t.string "name"
    t.boolean "public"
    t.string "certificate_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ssl_policy"
    t.index ["district_id", "name"], name: "index_endpoints_on_district_id_and_name", unique: true
    t.index ["district_id"], name: "index_endpoints_on_district_id"
  end

  create_table "env_vars", force: :cascade do |t|
    t.integer "heritage_id"
    t.string "key"
    t.text "encrypted_value"
    t.boolean "secret", default: false
    t.index ["heritage_id", "key"], name: "index_env_vars_on_heritage_id_and_key", unique: true
    t.index ["heritage_id"], name: "index_env_vars_on_heritage_id"
  end

  create_table "environments", force: :cascade do |t|
    t.bigint "heritage_id", null: false
    t.string "name", null: false
    t.text "value"
    t.text "value_from"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["heritage_id"], name: "index_environments_on_heritage_id"
  end

  create_table "heritages", force: :cascade do |t|
    t.string "name", null: false
    t.string "image_name"
    t.string "image_tag"
    t.integer "district_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "before_deploy"
    t.string "token"
    t.integer "version"
    t.text "scheduled_tasks"
    t.index ["district_id"], name: "index_heritages_on_district_id"
    t.index ["name"], name: "index_heritages_on_name", unique: true
  end

  create_table "listeners", force: :cascade do |t|
    t.integer "endpoint_id"
    t.integer "service_id"
    t.integer "health_check_interval"
    t.string "health_check_path"
    t.text "rule_conditions"
    t.integer "rule_priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_id", "service_id"], name: "index_listeners_on_endpoint_id_and_service_id", unique: true
    t.index ["endpoint_id"], name: "index_listeners_on_endpoint_id"
    t.index ["service_id"], name: "index_listeners_on_service_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "target", null: false
    t.string "endpoint", null: false
    t.integer "district_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["district_id"], name: "index_notifications_on_district_id"
  end

  create_table "oneoffs", force: :cascade do |t|
    t.string "task_arn"
    t.integer "heritage_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "command"
    t.index ["heritage_id"], name: "index_oneoffs_on_heritage_id"
  end

  create_table "plugins", force: :cascade do |t|
    t.integer "district_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "plugin_attributes"
    t.index ["district_id"], name: "index_plugins_on_district_id"
  end

  create_table "port_mappings", force: :cascade do |t|
    t.integer "host_port"
    t.integer "lb_port"
    t.integer "container_port"
    t.integer "service_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "protocol"
    t.boolean "enable_proxy_protocol", default: false
    t.index ["service_id"], name: "index_port_mappings_on_service_id"
  end

  create_table "releases", force: :cascade do |t|
    t.integer "heritage_id"
    t.text "description"
    t.text "heritage_params"
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["heritage_id"], name: "index_releases_on_heritage_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.integer "cpu"
    t.integer "memory"
    t.text "command"
    t.boolean "public"
    t.integer "heritage_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reverse_proxy_image"
    t.string "service_type", default: "default"
    t.boolean "force_ssl"
    t.text "hosts"
    t.text "health_check"
    t.index ["heritage_id"], name: "index_services_on_heritage_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "token_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "public_key"
    t.text "roles"
    t.string "auth"
    t.index ["name", "auth"], name: "index_users_on_name_and_auth", unique: true
    t.index ["token_hash"], name: "index_users_on_token_hash", unique: true
  end

  create_table "users_districts", force: :cascade do |t|
    t.integer "user_id"
    t.integer "district_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["district_id"], name: "index_users_districts_on_district_id"
    t.index ["user_id"], name: "index_users_districts_on_user_id"
  end

  add_foreign_key "endpoints", "districts"
  add_foreign_key "env_vars", "heritages"
  add_foreign_key "environments", "heritages", on_delete: :cascade
  add_foreign_key "heritages", "districts"
  add_foreign_key "listeners", "endpoints"
  add_foreign_key "listeners", "services"
  add_foreign_key "notifications", "districts"
  add_foreign_key "oneoffs", "heritages"
  add_foreign_key "plugins", "districts"
  add_foreign_key "port_mappings", "services"
  add_foreign_key "releases", "heritages"
  add_foreign_key "services", "heritages"
  add_foreign_key "users_districts", "districts"
  add_foreign_key "users_districts", "users"
end
