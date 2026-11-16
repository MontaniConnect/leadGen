# Deletes finished exports older than export.keep_days (files live in the database).
class CleanupExportsJob < ApplicationJob
  queue_as :default

  def perform
    Export.expired.delete_all
  end
end
