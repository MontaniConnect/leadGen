# Staffing, recruiting and outsourcing firms: a separate track from sales leads, with one partnership message each.
# They never appear in the lead queue and never count in the Results statistics.
class PartnersController < ApplicationController
  def index
    @candidates = Company.partner_candidates.includes(:selected_contact, :messages, :evaluations).order(:name)
    @dismissed = Company.partner_dismissed.order(:name)
    @step = Pipeline::Readiness.new(:partner)
    @formatter = Partnering::EvidenceFormatter.new
  end

  # "Not a staffing firm": removes it from Partners (and from drafting). Reversible.
  def dismiss
    Company.find(params[:id]).update!(partner_dismissed_at: Time.current)
    redirect_to partners_path, notice: "Removed from Partners. You can restore it at the bottom of the page."
  end

  def restore
    Company.find(params[:id]).update!(partner_dismissed_at: nil)
    redirect_to partners_path, notice: "Restored to Partners."
  end

  # Marks the partnership message sent (or back to unsent).
  def sent
    message = Company.find(params[:id]).messages.find_by!(label: "partnership")
    message.update!(status: message.status == "sent" ? "edited" : "sent")
    redirect_to partners_path
  end
end
