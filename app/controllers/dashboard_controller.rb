class DashboardController < ApplicationController
  LIST_LIMIT = 100

  def show
    report = Prefilter::Report.new
    @status_counts = report.status_counts
    @reason_counts = report.reason_counts
    @contact_counts = Company.prefilter_passed.group(:contact_status).count
    @companies = filtered_companies.includes(:selected_contact).order(prefilter_score: :desc, name: :asc).limit(LIST_LIMIT)
  end

  private

  def filtered_companies
    scope = Company.where.not(prefilter_status: "pending")
    scope = scope.where(prefilter_status: params[:status]) if params[:status].present?
    scope = scope.where("prefilter_reasons @> ?::jsonb", [ params[:reason] ].to_json) if params[:reason].present?
    scope
  end
end
