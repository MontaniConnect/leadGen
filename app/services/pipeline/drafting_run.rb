module Pipeline
  # Drafts messages for Hot companies without drafts as one tracked run, halting cleanly at the cap.
  class DraftingRun
    def initialize(gateway:, scope: Company.all, limit: nil, run: nil, drafter: nil, out: $stdout)
      @drafter = drafter || Drafting::CompanyDrafter.new(gateway: gateway)
      @scope = scope
      @limit = limit
      @run = run
      @out = out
    end

    def call
      work = lambda do |tracked|
        companies.each do |company|
          result = @drafter.call(company, run: tracked)
          @out.puts describe(company, result) if result
        end
      end
      run = @run ? PipelineRun.run_with(@run, &work) : PipelineRun.track("draft", &work)
      @out.puts Budget::RunSummary.new(run)
      run
    end

    private

    def companies
      Company.awaiting_drafts.where(id: @scope.select(:id)).includes(:pages, :selected_contact, :evaluations)
             .order(:id).limit(@limit)
    end

    def describe(company, result)
      return "#{company.name}: FAILED #{result.error}" unless result.status == "ok"

      "#{company.name}: #{result.messages.order(:id).pluck(:label).join(', ')}"
    end
  end
end
