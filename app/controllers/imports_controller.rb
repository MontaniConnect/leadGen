require "csv"

# Upload page for the Apollo exports. Importing is free (no paid calls, no web requests):
# it reads the file, runs the prefilter, and shows what passed and why the rest failed.
class ImportsController < ApplicationController
  DEFAULT_SAMPLE = 20
  SAMPLE_SEED = 42

  before_action :require_valid_upload, only: %i[accounts people]
  rescue_from CSV::MalformedCSVError, EncodingError do |error|
    redirect_to new_import_path, alert: "That file could not be read as a CSV: #{error.message.truncate(120)}"
  end

  def new
    @batches = ImportBatch.where(kind: %w[accounts people]).order(id: :desc).limit(10)
    @companies = Company.count
  end

  def accounts
    report = Imports::HeaderReport.new(:accounts).call(upload.tempfile.path)
    return reject_headers(report, "an Apollo accounts export") unless report.ok?

    batch, passed, failed = run_accounts_import
    return redirect_to(new_import_path, alert: "The file has a header row but no company rows.") if batch.rows_total.zero?

    Contacts::Runner.new.call
    redirect_to dashboard_path, notice: [ summary_line(batch), "Prefilter: #{passed} pass, #{failed} fail.", *report.warnings ].join("\n")
  end

  def people
    report = Imports::HeaderReport.new(:people).call(upload.tempfile.path)
    return reject_headers(report, "an Apollo people export") unless report.ok?

    batch = Imports::PeopleImporter.new(upload.tempfile.path).call
    batch.update!(filename: upload.original_filename)
    tally = Contacts::Runner.new.call
    redirect_to dashboard_path, notice: [ summary_line(batch), "Contacts: #{tally['selected']} companies have a contact, #{tally['not_found']} do not.", *report.warnings ].join("\n")
  end

  private

  def upload = params[:file]

  def require_valid_upload
    return redirect_to(new_import_path, alert: "Choose a CSV file first.") unless upload.respond_to?(:tempfile)
    return redirect_to(new_import_path, alert: "Only .csv files can be imported.") unless File.extname(upload.original_filename).casecmp?(".csv")

    limit = Setting.get("imports.max_upload_mb")
    redirect_to(new_import_path, alert: "That file is over #{limit} MB.") if upload.size > limit.megabytes
  end

  # Either everything, or a reproducible random sample to check by hand first (the pilot).
  def run_accounts_import
    path = upload.tempfile.path
    if params[:mode] == "all"
      batch = Imports::AccountsImporter.new(path).call
      tally = Prefilter::Runner.new.call
      counts = [ tally["pass"], tally["fail"] ]
    else
      batch = Pilot::Intake.new(path: path, count: sample_size, seed: SAMPLE_SEED, out: StringIO.new).call
      statuses = Pilot.scope.group(:prefilter_status).count
      counts = [ statuses["pass"], statuses["fail"] ]
    end
    batch.update!(filename: upload.original_filename)
    [ batch, counts[0].to_i, counts[1].to_i ]
  end

  def sample_size
    params[:sample_size].to_i.then { |n| n.positive? ? n : DEFAULT_SAMPLE }.clamp(1, Setting.get("imports.max_sample_rows"))
  end

  def summary_line(batch)
    "Imported #{batch.filename}: #{batch.rows_total} rows read, #{batch.rows_created} new, #{batch.rows_updated} updated, " \
      "#{batch.rows_unchanged} unchanged, #{batch.rows_skipped} skipped#{skip_detail(batch)}.#{merge_detail(batch)}"
  end

  # Rows that were the same business as one we already have (same website, or same name, city and country).
  def merge_detail(batch)
    merged = batch.notes[Imports::AccountsImporter::MERGED_NOTE].to_i
    merged.positive? ? " #{merged} #{'row was' if merged == 1}#{'rows were' if merged != 1} a duplicate of an existing company and was merged into it." : ""
  end

  def skip_detail(batch)
    return "" if batch.skip_reasons.empty?

    " (#{batch.skip_reasons.map { |reason, count| "#{reason.tr('_', ' ')}: #{count}" }.join(', ')})"
  end

  def reject_headers(report, what)
    found = report.headers.first(15).join(", ")
    redirect_to new_import_path,
                alert: "This doesn't look like #{what}. Missing: #{report.missing_required.join('; ')}. " \
                       "Columns found: #{found.presence || 'none'}#{'…' if report.headers.size > 15}."
  end
end
