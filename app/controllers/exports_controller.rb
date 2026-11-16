class ExportsController < ApplicationController
  MAX_UPLOAD_BYTES = 5.megabytes

  def index
    @exports = Export.order(id: :desc).limit(20)
  end

  # Small exports are built right away; large ones run as a background job.
  def create
    export = Export.new(file_format: params[:file_format], scope: params[:scope].presence || "view",
                        filters: Leads::Queue.new(**queue_params).filters)
    return redirect_to(leads_path(export.filters), alert: "Choose CSV or XLSX and a valid scope.") unless export.valid?

    rows = export.queue.count
    return redirect_to(leads_path(export.filters), alert: "Nothing to export for this view.") if rows.zero?

    export.save!
    rows <= Setting.get("export.inline_row_limit") ? Exports::Runner.new.call(export) : ExportJob.perform_later(export.id)
    redirect_to export_path(export)
  end

  def show
    @export = Export.find(params[:id])
  end

  def download
    export = Export.find(params[:id])
    return redirect_to(export_path(export)) unless export.done? && export.data

    send_data export.data, filename: export.filename, type: export.content_type, disposition: "attachment"
  end

  # Reads reply results back from an uploaded CSV, matched on Apollo Account Id.
  def import_replies
    upload = params[:file]
    return redirect_to(exports_path, alert: "Choose a CSV file first.") unless upload.respond_to?(:tempfile)
    return redirect_to(exports_path, alert: "Only .csv files can be imported.") unless File.extname(upload.original_filename).casecmp?(".csv")
    return redirect_to(exports_path, alert: "That file is over 5 MB.") if upload.size > MAX_UPLOAD_BYTES

    batch = Exports::RepliesImporter.new(upload.tempfile.path).call
    batch.update!(filename: upload.original_filename)
    redirect_to exports_path, notice: Imports::Summary.new(batch).to_s
  rescue CSV::MalformedCSVError => e
    redirect_to exports_path, alert: "That CSV could not be read: #{e.message.truncate(120)}"
  end

  private

  def queue_params
    { tier: params[:tier], status: params[:status], reply: params[:reply], batch: params[:batch] }
  end
end
