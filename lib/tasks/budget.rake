namespace :budget do
  desc "Set the spending cap in USD: bin/rails 'budget:cap[25]'"
  task :cap, [ :amount ] => :environment do |_, args|
    puts "Spending cap set to $#{format('%.2f', Budget::Cap.set!(args.fetch(:amount)))}"
  rescue Budget::Cap::Invalid => e
    abort e.message
  end

  desc "Show the cap, what has been spent and what is reserved"
  task status: :environment do
    ledger = Budget::Ledger.new
    puts "Cap:       #{ledger.cap ? format('$%.2f', ledger.cap) : 'NOT SET (paid runs are blocked)'}"
    puts format("Spent:     $%.4f", ledger.spent)
    puts format("Reserved:  $%.4f (batches not yet collected)", ledger.reserved)
    puts format("Remaining: $%.4f", ledger.remaining) if ledger.cap
  end

  desc "Estimate the cost of the next steps without calling a paid endpoint: bin/rails 'budget:estimate[limit]'  (EXACT=1 uses count_tokens, BATCH=1 prices batches)"
  task :estimate, [ :limit ] => :environment do |_, args|
    exact = ENV["EXACT"] == "1"
    counter = exact ? Budget::ExactTokenCounter.new(gateway: Scoring::AnthropicGateway.from_environment) : Budget::TokenEstimator.new
    dry_run = Budget::DryRun.new(counter: counter, sample_size: (Setting.get("estimates.exact_sample_size") if exact))
    result = dry_run.call(limit: args[:limit]&.to_i, batch: ENV["BATCH"] == "1")
    puts Budget::DryRunReport.new(result)
  end
end
