# The dashboard's step buttons: fetch pages (free), score and draft (paid, with safeguards).
class PipelineController < ApplicationController
  def fetch
    ids = Pipeline::Status.new.awaiting_fetch.pluck(:id)
    ActiveJob.perform_all_later(ids.map { |id| FetchCompanyPagesJob.new(id) })
    redirect_to dashboard_path, notice: if ids.empty?
      "Nothing to fetch: every company that passed already has its pages."
                                        else
      "Fetching pages for #{ids.size} #{'company'.pluralize(ids.size)}. This takes a few seconds each: refresh in a minute or two."
                                        end
  end

  def score = start("score", ScoringRunJob, "Scoring started")
  def draft = start("draft", DraftingRunJob, "Drafting started")

  # Partnership messages for staffing firms. Shares the "draft" lock, so it never runs alongside lead drafting.
  def partner_draft = start("draft", PartnerDraftingRunJob, "Partnership drafting started", step: :partner, back: partners_path)

  private

  # Paid steps: refuse with a reason, otherwise start a tracked run and do the work in the background.
  def start(kind, job, message, step: kind, back: dashboard_path)
    problem = Pipeline::Readiness.new(step).problem
    return redirect_to(back, alert: problem) if problem

    run = PipelineRun.start!(kind)
    job.perform_later(run.id)
    redirect_to back, notice: "#{message}. Refresh in a minute; the cost shows on the Spend page."
  rescue ActiveRecord::RecordNotUnique
    redirect_to back, alert: "A #{kind} run is already in progress. Wait for it to finish."
  end
end
