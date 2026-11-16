module Drafting
  # The per-company <lead> block: contact, the evaluation's findings, and page excerpts.
  class EvidenceFormatter
    PAGE_ORDER = %w[home about careers blog].freeze

    def initialize(page_words: Setting.get("drafting.page_words"))
      @page_words = page_words
    end

    def call(company)
      evaluation = company.current_evaluation
      <<~TEXT
        <lead>
        Company: #{company.name} (#{company.website.presence || company.domain})
        Contact first name: #{contact_first_name(company)}
        Contact title: #{company.selected_contact&.title.presence || 'Not found'}

        <assessment>
        Strongest signals:
        #{signals(evaluation.signals, "signal")}
        Red flags:
        #{signals(evaluation.red_flags, "flag")}
        Offshore signal: #{evaluation.offshore_signal}
        Why now: #{evaluation.why_now} (#{evaluation.why_now_source})
        Lead with: #{evaluation.lead_with}
        </assessment>
        #{pages(company)}
        </lead>

        Write the messages.
      TEXT
    end

    private

    def contact_first_name(company)
      company.selected_contact&.first_name.presence || "none"
    end

    def signals(items, key)
      return "- none" if items.blank?

      items.map { |item| "- #{item[key]} (source: #{item['source']})" }.join("\n")
    end

    def pages(company)
      usable = company.pages.select { |page| page.status == "ok" && page.text.present? }
      usable.sort_by { |page| PAGE_ORDER.index(page.kind) || PAGE_ORDER.size }.map do |page|
        %(<page kind="#{page.kind}" source="#{page.url}">\n#{page.text.split.first(@page_words).join(' ')}\n</page>)
      end.join("\n")
    end
  end
end
