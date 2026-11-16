# Pilot runbook: 20 companies before all 1,708

Nothing here sends a message or contacts anyone. Steps 3b and 3c spend real money on the Anthropic API;
everything else is free. All commands run from the project folder.

## 0. One-time setup
1. Put the API key in the environment (`export ANTHROPIC_API_KEY=...`) or `bin/rails credentials:edit` under `anthropic: api_key:`.
2. Set a spending cap. Paid runs are blocked until one is set: `bin/rails 'budget:cap[5]'`
   (or use the Spend page in the app). Check it any time with `bin/rails budget:status`.

## 1. Import 20 random rows and check every Pass/Fail by hand
```
bin/rails 'pilot:intake[path/to/apollo_accounts.csv,20,42]'
```
The last number is the random seed: the same seed gives the same 20 rows. It prints each decision with its
reason and writes `tmp/pilot_prefilter.csv` with an empty "Your verdict" column to mark up.
Look for: good companies that failed (and why), poor companies that passed.
To change a rule, then re-run the prefilter on the pilot:
```
bin/rails runner 'Setting.set("prefilter.min_employees", 15)'
bin/rails prefilter:run
```
Rules live in `config/settings_defaults.yml` under `prefilter:` and can be overridden with `Setting.set`.
Repeat step 1 until the decisions look right.

## 2. Contacts and pages (free, polite web requests)
```
bin/rails pilot:fetch
```
Shows which pages were fetched per company (`ok`, `not_found`, `blocked`, `empty`, `timeout`) and any
leader found on an About page.

## 3. Estimate, then score and draft
```
bin/rails pilot:estimate          # no paid calls; add EXACT=1 for exact token counts
bin/rails pilot:score             # paid, needs the cap
bin/rails pilot:draft             # paid, needs the cap: Hot leads only
```
Each paid step prints its tokens and cost and stops by itself if the next call could pass the cap.
Raising the cap and re-running continues where it stopped.

## 4. Judge the results
```
bin/rails pilot:report
```
Then open the app (`bin/rails server`) and read the Hot leads: evidence, source links, the three messages.
Also see the Spend page for tokens and cost per run.

## 5. Before the full run
- Compare the pilot's real cost per company with the estimate. If it differs a lot, adjust `estimates.*` in the settings.
- Run `bin/rails budget:estimate` for the full dry-run figure and set the cap with some headroom.
- For the full run, scoring in bulk is half price: `bin/rails score:batch` (results arrive within 24 hours;
  collect with `bin/rails score:collect`).
