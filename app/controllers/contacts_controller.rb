# Adds a contact a person researched themselves (for example by looking the company up on LinkedIn).
# It becomes the lead's contact and is never replaced by an automatic pick.
class ContactsController < ApplicationController
  def create
    lead = Company.find(params[:lead_id])
    contact = lead.contacts.new(contact_params.merge(source: "manual"))
    error = problem_with(contact)
    return redirect_to(return_path(lead), alert: error) if error

    Company.transaction do
      contact.save!
      lead.update!(selected_contact: contact, contact_status: "selected")
    end
    redirect_to return_path(lead), notice: "Contact saved: #{contact.full_name}."
  end

  private

  def contact_params
    raw = params.fetch(:contact, {}).permit(:first_name, :last_name, :title, :linkedin_url).to_h
    raw.transform_values { |value| value.to_s.squish.presence }.merge("linkedin_url" => raw["linkedin_url"].to_s.strip.presence)
  end

  def problem_with(contact)
    return "Enter at least a first or last name." if contact.first_name.blank? && contact.last_name.blank?
    return nil if contact.linkedin_url.blank? || Leads::LinkedinTarget.web_url(contact.linkedin_url)

    "The LinkedIn link must start with https:// (or leave it empty)."
  end

  # Partners are not on the lead screen (they have no score), so their form returns to the Partners page.
  def return_path(lead) = params[:return_to] == "partners" ? partners_path : lead_path(lead, filters)

  def filters
    Leads::Queue.new(tier: params[:tier], status: params[:status], reply: params[:reply], batch: params[:batch]).filters.symbolize_keys
  end
end
