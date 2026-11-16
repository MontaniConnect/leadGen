module Pipeline
  # Re-drafts messages that were written with an older prompt version, as one tracked run that halts at the cap.
  # Only companies whose messages are ALL unedited drafts are touched: anything a person edited or marked sent is left alone.
  class Redraft
    def initialize(gateway:, run: nil, out: $stdout, lead_drafter: nil, partner_drafter: nil)
      @lead_drafter = lead_drafter || Drafting::CompanyDrafter.new(gateway: gateway)
      @partner_drafter = partner_drafter || Partnering::Drafter.new(gateway: gateway)
      @run = run
      @out = out
    end

    def call
      work = lambda do |tracked|
        stale_leads.each { |company| report(company, @lead_drafter.call(company, force: true, run: tracked)) }
        stale_partners.each { |company| report(company, @partner_drafter.call(company, force: true, run: tracked)) }
      end
      run = @run ? PipelineRun.run_with(@run, &work) : PipelineRun.track("draft", &work)
      @out.puts Budget::RunSummary.new(run)
      run
    end

    def stale_leads
      version = Drafting::RequestBuilder.new.prompt_version
      outdated = Message.where.not(label: "partnership").where.not(prompt_version: version).select(:company_id)
      Company.draftable.where(id: outdated).where.not(id: touched_by_a_person).includes(:pages, :selected_contact, :evaluations).order(:name)
    end

    def stale_partners
      outdated = Message.where(label: "partnership").where.not(prompt_version: Partnering::Prompt::VERSION).select(:company_id)
      Company.partner_candidates.where(id: outdated).where.not(id: touched_by_a_person).includes(:pages, :selected_contact, :evaluations).order(:name)
    end

    private

    def touched_by_a_person = Message.where.not(status: "draft").select(:company_id)

    def report(company, result)
      return unless result

      @out.puts(result.status == "ok" ? "#{company.name}: re-drafted" : "#{company.name}: FAILED #{result.error}")
    end
  end
end
