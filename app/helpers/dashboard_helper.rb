module DashboardHelper
  def contact_label(company)
    return "" unless company.prefilter_status == "pass"
    return "Not found" unless company.selected_contact

    contact = company.selected_contact
    [ contact.full_name, contact.title ].compact_blank.join(", ")
  end
end
