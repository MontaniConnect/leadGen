namespace :score do
  desc "Score companies directly (pilot runs): bin/rails 'score:run[limit]'. Halts at the spending cap."
  task :run, [ :limit ] => :environment do |_, args|
    Pipeline::ScoringRun.new(gateway: Scoring::AnthropicGateway.from_environment, limit: args[:limit]&.to_i).call
  end

  desc "Re-score one company even if it was scored before: bin/rails 'score:company[ID]'"
  task :company, [ :id ] => :environment do |_, args|
    scorer = Scoring::CompanyScorer.new(gateway: Scoring::AnthropicGateway.from_environment)
    evaluation = scorer.call(Company.find(args.fetch(:id)), force: true)
    puts evaluation.status == "ok" ? "#{evaluation.tier} S#{evaluation.staffing_score}/A#{evaluation.automation_score}" : "FAILED #{evaluation.error}"
  rescue Budget::Guard::CapReached => e
    abort e.message
  end

  desc "Submit companies awaiting evaluation as Message Batches (reserves their worst case against the cap)"
  task batch: :environment do
    run = Pipeline::BatchSubmission.new(gateway: Scoring::AnthropicGateway.from_environment).call
    run.scoring_batches.each { |batch| CollectScoringBatchJob.set(wait: CollectScoringBatchJob::POLL_INTERVAL).perform_later(batch.id) }
  end

  desc "Collect any submitted batches that have finished"
  task collect: :environment do
    gateway = Scoring::AnthropicGateway.from_environment
    ScoringBatch.where(collected_at: nil).find_each do |batch|
      puts "#{batch.anthropic_batch_id}: #{Scoring::BatchCollector.new(gateway: gateway).call(batch)}"
    end
  end

  desc "List companies whose latest evaluation failed"
  task failed: :environment do
    Evaluation.failed.order(:id).each { |e| puts "#{e.company.name} (id #{e.company_id}): #{e.error}" }
  end
end
