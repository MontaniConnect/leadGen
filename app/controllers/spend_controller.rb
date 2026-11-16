class SpendController < ApplicationController
  def show
    @ledger = Budget::Ledger.new
    @by_model = by_model
    @runs = PipelineRun.order(id: :desc).limit(20).includes(:evaluations, :draft_runs)
  end

  def cap
    Budget::Cap.set!(params[:amount])
    redirect_to spend_path, notice: "Spending cap updated."
  rescue Budget::Cap::Invalid => e
    redirect_to spend_path, alert: e.message
  end

  private

  # { "model" => { calls:, input:, output:, cache_read:, cache_write:, cost: } } across scoring and drafting.
  def by_model
    [ Evaluation, DraftRun ].each_with_object({}) do |model, result|
      model.group(:model).pluck(:model, Arel.sql("COUNT(*)"), Arel.sql("SUM(tokens_in)"), Arel.sql("SUM(tokens_out)"),
                                Arel.sql("SUM(cache_read_tokens)"), Arel.sql("SUM(cache_write_tokens)"), Arel.sql("SUM(cost_usd)"))
           .each do |name, calls, input, output, cache_read, cache_write, cost|
        row = result[name] ||= Hash.new(0)
        row[:calls] += calls
        row[:input] += input.to_i
        row[:output] += output.to_i
        row[:cache_read] += cache_read.to_i
        row[:cache_write] += cache_write.to_i
        row[:cost] += cost.to_d
      end
    end
  end
end
