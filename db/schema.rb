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

ActiveRecord::Schema[8.1].define(version: 2026_11_16_063830) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.bigint "import_batch_id"
    t.string "name"
    t.string "account_stage"
    t.integer "employees"
    t.string "industry"
    t.string "website"
    t.string "domain"
    t.string "linkedin_url"
    t.string "city"
    t.string "state"
    t.string "country"
    t.text "keywords"
    t.text "technologies"
    t.bigint "total_funding"
    t.string "latest_funding"
    t.bigint "latest_funding_amount"
    t.date "last_raised_at"
    t.bigint "annual_revenue"
    t.string "apollo_account_id"
    t.string "sic_codes"
    t.string "naics_codes"
    t.text "short_description"
    t.integer "founded_year"
    t.string "intent_topic"
    t.integer "intent_score"
    t.jsonb "extra", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "prefilter_status", default: "pending", null: false
    t.jsonb "prefilter_reasons", default: [], null: false
    t.jsonb "prefilter_boosts", default: [], null: false
    t.integer "prefilter_score", default: 0, null: false
    t.datetime "prefiltered_at"
    t.string "contact_status", default: "pending", null: false
    t.bigint "selected_contact_id"
    t.datetime "connection_sent_at"
    t.string "reply_result"
    t.string "name_key"
    t.datetime "contact_researched_at"
    t.string "contact_research_result"
    t.datetime "partner_dismissed_at"
    t.index ["apollo_account_id"], name: "index_companies_on_apollo_account_id", unique: true
    t.index ["contact_status"], name: "index_companies_on_contact_status"
    t.index ["domain"], name: "index_companies_on_domain"
    t.index ["import_batch_id"], name: "index_companies_on_import_batch_id"
    t.index ["name_key"], name: "index_companies_on_name_key"
    t.index ["prefilter_status"], name: "index_companies_on_prefilter_status"
    t.index ["reply_result"], name: "index_companies_on_reply_result"
    t.index ["selected_contact_id"], name: "index_companies_on_selected_contact_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "title"
    t.string "linkedin_url"
    t.string "email"
    t.string "source", default: "apollo", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_contacts_on_company_id"
  end

  create_table "draft_runs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "status", default: "ok", null: false
    t.text "error"
    t.string "model"
    t.string "prompt_version"
    t.integer "tokens_in", default: 0, null: false
    t.integer "tokens_out", default: 0, null: false
    t.integer "cache_read_tokens", default: 0, null: false
    t.integer "cache_write_tokens", default: 0, null: false
    t.jsonb "raw", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cost_usd", precision: 12, scale: 6, default: "0.0", null: false
    t.bigint "pipeline_run_id"
    t.index ["company_id", "status"], name: "index_draft_runs_on_company_id_and_status"
    t.index ["company_id"], name: "index_draft_runs_on_company_id"
    t.index ["pipeline_run_id"], name: "index_draft_runs_on_pipeline_run_id"
  end

  create_table "evaluations", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "staffing_score"
    t.integer "automation_score"
    t.string "confidence"
    t.string "tier"
    t.jsonb "signals", default: [], null: false
    t.jsonb "red_flags", default: [], null: false
    t.string "offshore_signal"
    t.text "why_now"
    t.text "lead_with"
    t.string "model"
    t.integer "tokens_in"
    t.integer "tokens_out"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "ok", null: false
    t.text "error"
    t.boolean "disqualified", default: false, null: false
    t.string "why_now_source"
    t.string "prompt_version"
    t.integer "useful_sources"
    t.integer "cache_read_tokens", default: 0, null: false
    t.integer "cache_write_tokens", default: 0, null: false
    t.jsonb "raw", default: {}, null: false
    t.decimal "cost_usd", precision: 12, scale: 6, default: "0.0", null: false
    t.bigint "pipeline_run_id"
    t.index ["company_id", "status"], name: "index_evaluations_on_company_id_and_status"
    t.index ["company_id"], name: "index_evaluations_on_company_id"
    t.index ["pipeline_run_id"], name: "index_evaluations_on_pipeline_run_id"
    t.index ["tier"], name: "index_evaluations_on_tier"
  end

  create_table "exports", force: :cascade do |t|
    t.string "file_format", null: false
    t.string "scope", default: "view", null: false
    t.jsonb "filters", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "row_count"
    t.text "error"
    t.string "filename"
    t.string "content_type"
    t.binary "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_exports_on_created_at"
  end

  create_table "import_batches", force: :cascade do |t|
    t.string "kind", null: false
    t.string "filename"
    t.string "status", default: "pending", null: false
    t.integer "rows_total", default: 0, null: false
    t.integer "rows_created", default: 0, null: false
    t.integer "rows_updated", default: 0, null: false
    t.integer "rows_skipped", default: 0, null: false
    t.jsonb "skip_reasons", default: {}, null: false
    t.jsonb "skipped_rows", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "notes", default: {}, null: false
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "contact_id"
    t.string "label"
    t.text "body"
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "word_count", default: 0, null: false
    t.text "evidence"
    t.string "model"
    t.string "prompt_version"
    t.bigint "draft_run_id"
    t.index ["company_id", "label"], name: "index_messages_on_company_id_and_label"
    t.index ["company_id"], name: "index_messages_on_company_id"
    t.index ["contact_id"], name: "index_messages_on_contact_id"
    t.index ["draft_run_id"], name: "index_messages_on_draft_run_id"
  end

  create_table "pages", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "url"
    t.string "kind"
    t.text "text"
    t.datetime "fetched_at"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "http_status"
    t.jsonb "discovered_urls", default: {}, null: false
    t.integer "word_count", default: 0, null: false
    t.index ["company_id", "kind"], name: "index_pages_on_company_id_and_kind", unique: true
    t.index ["company_id"], name: "index_pages_on_company_id"
  end

  create_table "pipeline_runs", force: :cascade do |t|
    t.string "kind", null: false
    t.string "status", default: "running", null: false
    t.string "halted_reason"
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_pipeline_runs_one_active_per_kind", unique: true, where: "(((status)::text = 'running'::text) AND ((kind)::text = ANY ((ARRAY['score'::character varying, 'draft'::character varying])::text[])))"
  end

  create_table "scoring_batches", force: :cascade do |t|
    t.string "anthropic_batch_id", null: false
    t.string "status", default: "submitted", null: false
    t.string "model"
    t.integer "requests_count", default: 0, null: false
    t.integer "succeeded", default: 0, null: false
    t.integer "errored", default: 0, null: false
    t.jsonb "company_ids", default: [], null: false
    t.datetime "collected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "reserved_usd", precision: 12, scale: 6, default: "0.0", null: false
    t.bigint "pipeline_run_id"
    t.index ["anthropic_batch_id"], name: "index_scoring_batches_on_anthropic_batch_id", unique: true
    t.index ["pipeline_run_id"], name: "index_scoring_batches_on_pipeline_run_id"
  end

  create_table "sends", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "contact_id"
    t.bigint "message_id"
    t.string "variant"
    t.string "assignment", default: "random", null: false
    t.datetime "connection_sent_at", null: false
    t.boolean "connection_accepted", default: false, null: false
    t.text "sent_body"
    t.integer "word_count"
    t.datetime "sent_at"
    t.boolean "replied", default: false, null: false
    t.boolean "positive_reply", default: false, null: false
    t.boolean "call_booked", default: false, null: false
    t.datetime "replied_at"
    t.string "tier"
    t.integer "staffing_score"
    t.integer "automation_score"
    t.string "confidence"
    t.string "industry"
    t.integer "employee_count"
    t.string "contact_title"
    t.boolean "had_why_now", default: false, null: false
    t.jsonb "signal_tags", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_sends_on_company_id", unique: true
    t.index ["contact_id"], name: "index_sends_on_contact_id"
    t.index ["message_id"], name: "index_sends_on_message_id"
    t.index ["sent_at"], name: "index_sends_on_sent_at"
    t.index ["tier"], name: "index_sends_on_tier"
    t.index ["variant"], name: "index_sends_on_variant"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.jsonb "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  add_foreign_key "companies", "contacts", column: "selected_contact_id", on_delete: :nullify
  add_foreign_key "companies", "import_batches"
  add_foreign_key "contacts", "companies"
  add_foreign_key "draft_runs", "companies"
  add_foreign_key "draft_runs", "pipeline_runs", on_delete: :nullify
  add_foreign_key "evaluations", "companies"
  add_foreign_key "evaluations", "pipeline_runs", on_delete: :nullify
  add_foreign_key "messages", "companies"
  add_foreign_key "messages", "contacts"
  add_foreign_key "messages", "draft_runs", on_delete: :nullify
  add_foreign_key "pages", "companies"
  add_foreign_key "scoring_batches", "pipeline_runs", on_delete: :nullify
  add_foreign_key "sends", "companies"
  add_foreign_key "sends", "contacts", on_delete: :nullify
  add_foreign_key "sends", "messages", on_delete: :nullify
end
