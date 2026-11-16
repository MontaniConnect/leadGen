module Outreach
  # Moves a lead's send through its lifecycle. Every method returns the OutreachSend. The company's own
  # connection_sent_at is kept in step because the queue filters and exports read it.
  class Tracker
    class Rejected < StandardError; end

    def initialize(assigner: VariantAssigner.new, segments: Segments.new)
      @assigner = assigner
      @segments = segments
    end

    # The connection request went out. Snapshots the lead and assigns a variant.
    def connection_sent!(company, at: Time.current)
      raise Rejected, "This lead has no evaluation yet." unless company.current_evaluation
      raise Rejected, "A send is already recorded for this lead." if company.outreach_send

      send_record = OutreachSend.new(company: company, contact: company.selected_contact, connection_sent_at: at,
                                     **Snapshot.call(company))
      choice = @assigner.call(labels: company.messages.map(&:label), segments: @segments.for(send_record))
      send_record.assign_attributes(variant: choice.variant, assignment: choice.assignment,
                                    message: message_for(company, choice.variant))
      OutreachSend.transaction do
        send_record.save!
        company.update!(connection_sent_at: at)
      end
      send_record
    end

    # Undo "connection sent". Refused once the message has been sent, so recorded outcomes are never lost.
    def undo_connection!(send_record)
      raise Rejected, "Undo the sent message first." if send_record.messaged? || send_record.replied

      OutreachSend.transaction do
        send_record.company.update!(connection_sent_at: nil)
        send_record.destroy!
      end
    end

    def toggle_accepted!(send_record)
      raise Rejected, "The message was already sent, so the connection was accepted." if send_record.messaged? || send_record.replied

      send_record.update!(connection_accepted: !send_record.connection_accepted)
      send_record
    end

    # A person picks a different variant than the assigned one.
    def change_variant!(send_record, label)
      raise Rejected, "The message was already sent." if send_record.messaged?
      raise Rejected, "This lead has no #{label} draft." unless send_record.company.messages.exists?(label: label)

      send_record.update!(variant: label, assignment: "manual", message: message_for(send_record.company, label))
      send_record
    end

    # The message went out. Stores the exact text sent (the on-screen text, edits included), not the draft.
    def message_sent!(send_record, body: nil, at: Time.current)
      message = send_record.message
      raise Rejected, "There is no drafted message to send." unless message

      text = body.presence || message.body
      OutreachSend.transaction do
        send_record.update!(sent_body: text.to_s.strip, sent_at: at, connection_accepted: true)
        message.update!(status: "sent")
      end
      send_record
    end

    def undo_message!(send_record)
      raise Rejected, "A reply is already recorded." if send_record.replied

      OutreachSend.transaction do
        send_record.update!(sent_body: nil, sent_at: nil, word_count: nil)
        send_record.message&.update!(status: "edited")
      end
      send_record
    end

    private

    def message_for(company, label)
      company.messages.find { |message| message.label == label }
    end
  end
end
