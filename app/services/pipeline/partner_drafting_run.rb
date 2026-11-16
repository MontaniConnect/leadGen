module Pipeline
  # Drafts partnership messages for staffing-firm candidates as one tracked run, halting cleanly at the cap.
  # Uses the "draft" run kind, so it never overlaps with a lead-drafting run.
  class PartnerDraftingRun
    def initialize(gateway:, scope: Company.all, limit: nil, run: nil, drafter: nil, out: $stdout)
      @drafter = drafter || Partnering::Drafter.new(gateway: gateway)
      @scope = scope
      @limit = limit
      @run = run
      @out = out
    end

    def call
      work = lambda do |tracked|
        companies.each do |company|
          result = @drafter.call(company, run: tracked)
          @out.puts(result.status == "ok" ? "#{company.name}: partnership message drafted" : "#{company.name}: FAILED #{result.error}") if result
        end
      end
      run = @run ? PipelineRun.run_with(@run, &work) : PipelineRun.track("draft", &work)
      @out.puts Budget::RunSummary.new(run)
      run
    end

    private

    def companies
      Company.awaiting_partner_drafts.where(id: @scope.select(:id)).includes(:pages, :selected_contact, :evaluations).order(:name).limit(@limit)
    end
  end
end
