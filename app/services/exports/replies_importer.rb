module Exports
  # Reads reply results back from a CSV (an exported sheet someone filled in), matching on Apollo Account Id.
  # Accepts the labels used in the export ("No reply") or the stored keys ("no_reply"). A blank cell means
  # "no change", never "clear". Idempotent. A reply for a lead with no logged send updates the lead only, and is noted.
  class RepliesImporter
    def initialize(path, rows: nil)
      @path = path
      @rows = rows || Imports::CsvRows.new(path)
    end

    def call
      batch = ImportBatch.create!(kind: "replies", filename: File.basename(@path), status: "running")
      tally = Imports::Tally.new
      @rows.each { |line, row| import_row(tally, line, row) }
      tally.apply_to(batch)
      batch
    rescue StandardError
      batch&.update(status: "failed")
      raise
    end

    private

    def import_row(tally, line, row)
      tally.row!
      cells = row.transform_keys { |header| normalize(header) }
      account_id = cells["apolloaccountid"].to_s.strip
      value = cells["replyresult"].to_s.strip
      return tally.skip!(line, "blank_reply_result") if value.empty?
      return tally.skip!(line, "missing_apollo_account_id") if account_id.empty?

      result = reply_key(value)
      return tally.skip!(line, "invalid_reply_result") unless result

      company = Company.find_by(apollo_account_id: account_id)
      return tally.skip!(line, "unknown_company") unless company
      return if company.reply_result == result

      outcome = Outreach::ReplyRecorder.new.call(company, result)
      tally.note!("recorded_without_a_send_record") unless outcome.send_record
      tally.updated!
    rescue Outreach::ReplyRecorder::NotMessaged
      tally.skip!(line, "message_not_marked_sent")
    end

    def reply_key(value)
      Company::REPLY_RESULTS.find { |key, label| [ key, label ].any? { |name| normalize(name) == normalize(value) } }&.first
    end

    def normalize(text) = text.to_s.downcase.gsub(/[^a-z0-9]/, "")
  end
end
