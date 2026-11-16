# Looks for a contact on one company's website, in the background.
class FindContactJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(company_id, researcher: Contacts::WebsiteResearch.new)
    researcher.call(Company.find(company_id))
  end
end
