namespace :pilot do
  desc "Step 1: import a random sample and show every Pass/Fail for hand review: bin/rails 'pilot:intake[path/to/accounts.csv,20,42]'"
  task :intake, [ :path, :count, :seed ] => :environment do |_, args|
    Pilot::Intake.new(path: args.fetch(:path), count: (args[:count] || 20).to_i, seed: (args[:seed] || 42).to_i).call
  end

  desc "Step 2: choose contacts and fetch pages for the pilot companies that passed (no paid calls)"
  task fetch: :environment do
    Pilot::Fetch.new.call
  end

  desc "Step 3a: estimate the cost of scoring and drafting the pilot (no paid calls). EXACT=1 for exact token counts."
  task estimate: :environment do
    exact = ENV["EXACT"] == "1"
    counter = exact ? Budget::ExactTokenCounter.new(gateway: Scoring::AnthropicGateway.from_environment) : Budget::TokenEstimator.new
    result = Budget::DryRun.new(counter: counter, sample_size: (Setting.get("estimates.exact_sample_size") if exact)).call(scope: Pilot.scope)
    puts Budget::DryRunReport.new(result)
  end

  desc "Step 3b: score the pilot companies (paid; needs a cap)"
  task score: :environment do
    Pipeline::ScoringRun.new(gateway: Scoring::AnthropicGateway.from_environment, scope: Pilot.scope).call
  end

  desc "Step 3c: draft messages for the pilot's Hot companies (paid; needs a cap)"
  task draft: :environment do
    Pipeline::DraftingRun.new(gateway: Scoring::AnthropicGateway.from_environment, scope: Pilot.scope).call
  end

  desc "Step 4: one line per pilot company: prefilter, contact, pages, tier, scores, drafts, cost"
  task report: :environment do
    Pilot::Report.new.call
  end
end
