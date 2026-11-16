module Fetching
  # Fetches home, about, careers and blog for one company and stores them as Pages.
  # If the company has no selected contact, tries to read a leader off the about page (source: site).
  class CompanyFetcher
    Outcome = Data.define(:pages_fetched, :pages_skipped, :site_contact)

    def initialize(page_fetcher_factory: nil, text_extractor: nil, link_discoverer: LinkDiscoverer.new,
                   contact_extractor: nil, refetch_days: nil, min_words: nil, clock: -> { Time.current })
      @page_fetcher_factory = page_fetcher_factory || default_factory
      @text_extractor = text_extractor || TextExtractor.new(max_words: Setting.get("fetching.max_words"))
      @link_discoverer = link_discoverer
      @contact_extractor = contact_extractor || SiteContactExtractor.new
      @refetch_days = refetch_days || Setting.get("fetching.refetch_after_days")
      @min_words = min_words || Setting.get("fetching.min_words")
      @clock = clock
    end

    # force: page kinds to re-fetch even if fetched recently (used to re-read an About page for a leader).
    # kinds: which discovered pages to fetch besides the home page.
    def call(company, force: [], kinds: %w[about careers blog])
      base = base_url(company)
      return Outcome.new(0, 0, nil) unless base

      fetcher = @page_fetcher_factory.call
      @fetched = 0
      @skipped = 0
      @force = force
      home, = fetch_kind(company, "home", base, fetcher)
      about_html = nil
      home.discovered_urls.slice(*kinds).each do |kind, url|
        page, html = fetch_kind(company, kind, url, fetcher)
        about_html = html if kind == "about" && page.status == "ok"
      end
      Outcome.new(@fetched, @skipped, about_html && save_site_contact(company, about_html))
    end

    private

    def default_factory
      lambda do
        user_agent = Setting.get("fetching.user_agent")
        http = HttpClient.from_settings
        limiter = RateLimiter.new(delay: Setting.get("fetching.delay_seconds"))
        PageFetcher.new(http: http, limiter: limiter, robots: RobotsPolicy.new(http: http, limiter: limiter, user_agent: user_agent))
      end
    end

    def base_url(company)
      return nil if company.domain.blank?

      "https://#{company.domain}/"
    end

    # Returns [page, html_or_nil]. A fresh page is reused and html is nil.
    def fetch_kind(company, kind, url, fetcher)
      page = company.pages.find_or_initialize_by(kind: kind)
      if !@force.include?(kind) && page.fresh?(days: @refetch_days, now: @clock.call)
        @skipped += 1
        return [ page, nil ]
      end

      result = fetcher.call(url)
      @fetched += 1
      store(page, url, result)
      [ page, result.html.presence ]
    end

    def store(page, url, result)
      text = result.status == "ok" ? @text_extractor.call(result.html) : ""
      words = text.split.size
      status = result.status == "ok" && words < @min_words ? "empty" : result.status
      page.assign_attributes(
        url: result.url.presence || url, status: status, http_status: result.http_status,
        text: status == "ok" ? text : nil, word_count: status == "ok" ? words : 0, fetched_at: @clock.call,
        discovered_urls: page.kind == "home" && result.status == "ok" ? @link_discoverer.call(result.html, result.url) : {}
      )
      page.save!
    end

    def save_site_contact(company, html)
      return nil if company.contact_status == "selected"

      found = @contact_extractor.call(html)
      return nil unless found
      return nil if company.contacts.exists?(first_name: found[:first_name], last_name: found[:last_name])

      company.contacts.create!(found.merge(source: "site"))
    end
  end
end
