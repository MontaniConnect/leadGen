# Records what actually happens with a lead: connection sent, accepted, message sent, reply.
# Each action redirects back to the lead screen with the queue filters kept.
class OutreachesController < ApplicationController
  before_action :set_lead
  rescue_from Outreach::Tracker::Rejected, Outreach::ReplyRecorder::NotMessaged, with: :rejected
  rescue_from ActiveRecord::RecordInvalid, with: :rejected

  def create
    tracker.connection_sent!(@lead)
    back
  end

  def destroy
    tracker.undo_connection!(current_send)
    back
  end

  def accepted
    tracker.toggle_accepted!(current_send)
    back
  end

  def variant
    tracker.change_variant!(current_send, params[:variant].to_s)
    back
  end

  # Stores the exact text on screen when the button was pressed (sent_body), not just the saved draft.
  def message_sent
    tracker.message_sent!(current_send, body: params[:sent_body])
    back
  end

  def undo_message
    tracker.undo_message!(current_send)
    back
  end

  def reply
    result = params[:reply_result].to_s
    raise Outreach::Tracker::Rejected, "Unknown reply result." unless result.blank? || Company::REPLY_RESULTS.key?(result)

    Outreach::ReplyRecorder.new.call(@lead, result)
    back
  end

  private

  def set_lead
    @lead = Company.preload(:messages, :evaluations, :selected_contact).find(params[:lead_id])
  end

  def tracker = Outreach::Tracker.new

  def current_send
    @lead.outreach_send || raise(Outreach::Tracker::Rejected, "Mark the connection request sent first.")
  end

  def filters
    Leads::Queue.new(tier: params[:tier], status: params[:status], reply: params[:reply], batch: params[:batch]).filters.symbolize_keys
  end

  def back(**flash_options)
    redirect_to lead_path(@lead, filters), status: :see_other, **flash_options
  end

  def rejected(error)
    redirect_to lead_path(@lead, filters), status: :see_other, alert: error.message
  end
end
