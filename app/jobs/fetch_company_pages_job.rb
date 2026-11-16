# Fetches one company's pages, then re-runs contact selection for it (a site contact may have been found).
class FetchCompanyPagesJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(company_id, fetcher: Fetching::CompanyFetcher.new)
    company = Company.find(company_id)
    fetcher.call(company)
    Contacts::Runner.new(scope: Company.where(id: company.id).prefilter_passed).call
  end
end
