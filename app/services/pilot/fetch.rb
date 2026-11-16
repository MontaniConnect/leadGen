module Pilot
  # Step 2 of the pilot: choose contacts, then fetch pages for the pilot companies that passed.
  # Free to run (no paid API), but it does make polite web requests to each company's site.
  class Fetch
    def initialize(fetcher: Fetching::CompanyFetcher.new, out: $stdout)
      @fetcher = fetcher
      @out = out
    end

    def call
      Contacts::Runner.new(scope: Pilot.scope.prefilter_passed).call
      Pilot.scope.prefilter_passed.where.not(domain: nil).order(:name).each do |company|
        outcome = @fetcher.call(company)
        Contacts::Runner.new(scope: Company.where(id: company.id)).call
        statuses = company.pages.reload.order(:kind).pluck(:kind, :status).map { |kind, status| "#{kind}=#{status}" }.join(" ")
        @out.puts "#{company.name} (#{company.domain}): #{statuses}#{' +site contact' if outcome.site_contact}"
      end
    end
  end
end
