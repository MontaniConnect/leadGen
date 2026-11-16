module Outreach
  # Records a reply result on the lead and on its send. The one place both are updated, so the lead
  # screen, a sheet re-import and the Results page can never disagree.
  #
  # A reply is only counted against a send whose message was marked sent: otherwise there is no variant to
  # credit and the Results numbers would not add up. That case raises NotMessaged and changes nothing.
  class ReplyRecorder
    class NotMessaged < StandardError
      def initialize(message = "Mark the message as sent first, so the reply is counted under the right variant.")
        super
      end
    end

    Outcome = Data.define(:company, :send_record)

    # result: a Company::REPLY_RESULTS key, or blank to clear. send_record is nil when no send was logged
    # (e.g. the message went out before this app was used): the lead is updated, the Results page cannot count it.
    def call(company, result, at: Time.current)
      result = result.presence
      send_record = company.outreach_send
      raise NotMessaged if send_record && result && !send_record.messaged?

      OutreachSend.transaction do
        company.update!(reply_result: result)
        send_record&.record_reply_result!(result, at: at)
      end
      Outcome.new(company, send_record)
    end
  end
end
