# leadGen

A lead qualification app for Montani International. It turns an Apollo accounts export into ranked
**Hot / Warm / Cold** leads, each with a decision-maker, evidence with sources, and short personalized
LinkedIn messages. A separate **Partners** track handles staffing, recruiting and outsourcing firms.

**Nothing is ever sent automatically.** The app drafts; a person reviews, copies and sends.

## How it works

1. **Import** an Apollo accounts CSV (and optionally the people CSV) from the Import page. Duplicate companies merge.
2. **Prefilter** (free, no model): size, country, excluded industries. Every Fail shows its reason.
3. **Fetch pages** (free, polite, obeys robots.txt) and **look for contacts** on each company's own site.
4. **Score** with Claude Haiku: two fit scores, evidence with sources, red flags, "why now". Tier comes from rules in code.
5. **Draft messages** with Claude Sonnet for Hot and Warm leads (under 50 words, checked in code), and one partnership message per staffing firm.
6. **Review and send** from the lead screen, then log replies. The Results page shows what works, with "too few to judge" below 30 sends.

Cost is controlled by design: code filters first, prompts are cached, bulk scoring can use the Batches API,
and every paid step shows an estimate, asks for confirmation and **stops at a spending cap**. With no cap set, paid runs are blocked.

## Stack

Rails 8.1, PostgreSQL, Solid Queue, Hotwire (Turbo + Stimulus), Minitest + Capybara. Claude via the official `anthropic` gem.

## Setup

```
bundle install
bin/rails db:create db:migrate
EDITOR="nano" bin/rails credentials:edit     # add:  anthropic:\n  api_key: sk-ant-...
bin/rails 'budget:cap[5]'                      # paid runs are blocked until a cap is set
bin/rails server
```

The API key can also come from the `ANTHROPIC_API_KEY` environment variable. Never commit `config/master.key`.
The first run should be the 20-row pilot: see [docs/PILOT.md](docs/PILOT.md).

## Tests

```
bin/rails test           # unit and integration
bin/rails test:system    # browser tests (headless Chrome)
bin/rubocop
```

## Privacy

Only what Apollo exports and what you add is stored: names, titles, LinkedIn URLs, message text and outcomes.
LinkedIn is never scraped. Company data and API keys do not belong in this repository.
