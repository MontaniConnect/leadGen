# A requested export of leads (CSV or XLSX) and, once built, its file. Files are kept in the database
# for a few days (see CleanupExportsJob) so no file storage is needed.
class Export < ApplicationRecord
  FORMATS = {
    "csv" => { extension: "csv", content_type: "text/csv; charset=utf-8" },
    "xlsx" => { extension: "xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
  }.freeze
  SCOPES = %w[view all].freeze
  STATUSES = %w[pending running done failed].freeze

  validates :file_format, inclusion: { in: FORMATS.keys }
  validates :scope, inclusion: { in: SCOPES }
  validates :status, inclusion: { in: STATUSES }

  scope :expired, ->(days = Setting.get("export.keep_days")) { where(created_at: ...days.days.ago) }

  # The lead set this export contains: the saved filters, or every scored lead.
  def queue
    return Leads::Queue.new(all_tiers: true) if scope == "all"

    Leads::Queue.new(**filters.symbolize_keys.slice(:tier, :status, :reply, :batch))
  end

  def done? = status == "done"
  def failed? = status == "failed"
  def finished? = done? || failed?
  def extension = FORMATS.fetch(file_format)[:extension]
  def label = scope == "all" ? "All scored leads" : "#{queue.tier} view"
end
