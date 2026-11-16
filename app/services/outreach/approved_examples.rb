module Outreach
  # The anonymised past messages a person approved as drafting examples. Only messages that earned a
  # positive reply can be approved, and only they are ever returned.
  module ApprovedExamples
    def self.call(approvals: Approvals.new, max: Setting.get("results.max_examples"))
      OutreachSend.messaged.where(positive_reply: true, id: approvals.example_ids)
                  .includes(:contact, :company).order(:id).limit(max).map { |record| Anonymizer.call(record) }
    end
  end
end
