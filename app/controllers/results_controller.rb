class ResultsController < ApplicationController
  def show
    sends = OutreachSend.includes(:contact, :company).to_a
    @report = Outreach::Report.new(sends: sends)
    @suggestions = Outreach::Suggestions.new(sends: sends)
    @approvals = Outreach::Approvals.new
    @random_share = [ sends.count { |record| record.messaged? && record.assignment == "random" }, @report.messaged.size ]
  end

  # Only a suggestion the data currently supports can be approved, never an arbitrary variant.
  def approve_default
    match = suggestions.variant_defaults.find do |suggestion|
      [ suggestion.dimension, suggestion.segment, suggestion.variant ] == params.values_at(:dimension, :segment, :variant)
    end
    return redirect_to(results_path, alert: "That suggestion is not supported by enough data.") unless match

    approvals.approve_default!(match.dimension, match.segment, match.variant)
    redirect_to results_path, notice: "Approved: #{match.variant_name} for #{match.dimension} #{match.segment}."
  end

  def revoke_default
    approvals.revoke_default!(params[:key].to_s)
    redirect_to results_path, notice: "Default removed."
  end

  # Only a message that earned a positive reply can become a drafting example.
  def approve_example
    candidate = suggestions.example_candidates.find { |example| example.send_record.id == params[:send_id].to_i }
    return redirect_to(results_path, alert: "That message cannot be used as an example yet.") unless candidate

    approvals.approve_example!(candidate.send_record.id)
    redirect_to results_path, notice: "Approved. New drafts will see it as a style example."
  end

  def revoke_example
    approvals.revoke_example!(params[:send_id])
    redirect_to results_path, notice: "Example removed."
  end

  private

  def suggestions = Outreach::Suggestions.new(sends: OutreachSend.includes(:contact, :company).to_a)
  def approvals = Outreach::Approvals.new
end
