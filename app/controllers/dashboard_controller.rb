class DashboardController < ApplicationController
  LIST_LIMIT = 100

  def show
    report = Prefilter::Report.new
    @status_counts = report.status_counts
    @pipeline = Pipeline::Status.new
    @score_step = Pipeline::Readiness.new(:score)
    @draft_step = Pipeline::Readiness.new(:draft)
    @reason_counts = report.reason_counts
    @contact_counts = Company.prefilter_passed.group(:contact_status).count
    @lookup_count = ContactResearchController.lookup_scope.count
    @checked_without_name = Company.prefilter_passed.where.not(contact_status: "selected").where(contact_research_result: %w[no_clear_name site_unreachable]).count
    @sort_dir = sort_by_why? ? why_direction : nil
    @companies = ordered(filtered_companies.includes(:selected_contact, :evaluations)).limit(LIST_LIMIT)
  end

  helper_method :list_filters

  private

  # The first reason (for failed companies) or first boost (for passed ones), the same text the Why column shows.
  WHY_SQL = "CASE WHEN prefilter_status = 'fail' THEN prefilter_reasons->>0 ELSE prefilter_boosts->>0 END".freeze

  def sort_by_why? = params[:sort] == "why"
  def why_direction = params[:dir] == "desc" ? "desc" : "asc"

  def ordered(scope)
    return scope.order(prefilter_score: :desc, name: :asc) unless sort_by_why?

    scope.order(Arel.sql("#{WHY_SQL} #{why_direction.upcase} NULLS LAST, companies.name ASC"))
  end

  # Filters kept when a column header is clicked.
  def list_filters = params.permit(:status, :reason).to_h.symbolize_keys

  def filtered_companies
    scope = Company.where.not(prefilter_status: "pending")
    scope = scope.where(prefilter_status: params[:status]) if params[:status].present?
    scope = scope.where("prefilter_reasons @> ?::jsonb", [ params[:reason] ].to_json) if params[:reason].present?
    scope
  end
end
