# On a single database (Railway gives us one DATABASE_URL), Rails sees the Solid Queue, Cache and Cable
# configurations as "the database already exists" and never loads their schemas, so their tables would be
# missing and background jobs would fail. This creates them in the main database when they are absent.
# It is safe to run again: a table that already exists is never touched.
class CreateSolidTablesInPrimary < ActiveRecord::Migration[8.1]
  SCHEMAS = {
    "solid_queue_jobs" => "queue_schema.rb",
    "solid_cache_entries" => "cache_schema.rb",
    "solid_cable_messages" => "cable_schema.rb"
  }.freeze

  def up
    SCHEMAS.each do |table, file|
      next if table_exists?(table)

      load Rails.root.join("db", file)
    end
  end

  def down
    # Deliberately empty: these tables may hold queued jobs, and the other configurations manage them too.
  end
end
