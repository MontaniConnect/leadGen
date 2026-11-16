namespace :draft do
  desc "Draft message variants for Hot companies without drafts: bin/rails 'draft:run[limit]'. Halts at the spending cap."
  task :run, [ :limit ] => :environment do |_, args|
    Pipeline::DraftingRun.new(gateway: Scoring::AnthropicGateway.from_environment, limit: args[:limit]&.to_i).call
  end

  desc "Re-draft one company (replaces its unedited drafts): bin/rails 'draft:company[ID]'"
  task :company, [ :id ] => :environment do |_, args|
    drafter = Drafting::CompanyDrafter.new(gateway: Scoring::AnthropicGateway.from_environment)
    run = drafter.call(Company.find(args.fetch(:id)), force: true)
    puts run ? (run.status == "ok" ? run.messages.map { |m| "[#{m.label}] #{m.body}" } : "FAILED #{run.error}") : "not a Hot company"
  rescue Budget::Guard::CapReached => e
    abort e.message
  end
end
