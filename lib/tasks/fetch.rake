namespace :fetch do
  desc "Enqueue page fetching for prefilter-passed companies: bin/rails 'fetch:enqueue[limit]'"
  task :enqueue, [ :limit ] => :environment do |_, args|
    scope = Company.prefilter_passed.where.not(domain: nil).order(prefilter_score: :desc, id: :asc)
    scope = scope.limit(args[:limit].to_i) if args[:limit].present?
    scope.each { |company| FetchCompanyPagesJob.perform_later(company.id) }
    puts "enqueued #{scope.size} companies"
  end

  desc "Fetch synchronously (pilot runs): bin/rails 'fetch:inline[limit]'"
  task :inline, [ :limit ] => :environment do |_, args|
    scope = Company.prefilter_passed.where.not(domain: nil).order(prefilter_score: :desc, id: :asc)
    scope = scope.limit(args[:limit].to_i) if args[:limit].present?
    scope.each do |company|
      outcome = Fetching::CompanyFetcher.new.call(company)
      Contacts::Runner.new(scope: Company.where(id: company.id)).call
      statuses = company.pages.reload.pluck(:kind, :status).map { |k, s| "#{k}=#{s}" }.join(" ")
      puts "#{company.name} (#{company.domain}): #{statuses}#{' +site contact' if outcome.site_contact}"
    end
  end
end
