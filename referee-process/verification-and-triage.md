# Verification of the response letter and triage of the referee companion

**Date:** 2026-10-22
**Manuscript:** R Journal 2026-95, *tidyfinance: Transparent Factor Construction for Empirical Asset Pricing*
**Purpose:** (1) confirm that every claim in `response-letter.md` is actually implemented in
`r-tidyfinance` and implemented correctly; (2) list the points in the editor/referee letters not yet
fully closed; (3) triage the optional recommendations in the referee companion
(`RJournal_2026-95_referee/`).

**Method:** each claim traced to the `r-tidyfinance` source, its unit tests, and the git history.
Code references below are to `r-tidyfinance` unless noted; paper references are to `tidyfinance.Rmd`.

---

## 0. Version anchor

- `renv.lock` pins `tidyfinance 0.9.0.9007`, `RemoteSha = e07e65041a8bd086756f6850df2ed0141dc0a3c6`.
- That commit is the merge of **PR #334 (`staggered-rebalancing`)** and `DESCRIPTION` there reads
  `Version: 0.9.0.9007`. It already contains **all** the fixes below, so the paper's numbers come from a
  package that has every correction, staggered rebalancing included.
- Current `main` is `0.9.0.9009`. The only commits after the pin are **PR #335** (README `remotes`
  install) and **PR #336** (factor-library revisions/costs/persistence); neither touches any function
  the paper uses. The sole later edit to `staggered_portfolios.R` is a one-word roxygen cosmetic.
- Consequence: if the pin is ever bumped, the manuscript must be re-rendered (the computational-details
  version is read from `renv.lock` at render time).

---

## 1. Response-letter claims — all implemented and correct

| Claim in the letter | Where implemented | Status |
|---|---|---|
| **Delisting returns** kept in CRSP v2 (PR #316) | `download_data_wrds_crsp.R`: common-stock screens matched with `between(pmin(mthcaldt, securityenddt), secinfostartdt, secinfoenddt)`; the daily branch uses the same `pmin(dlycaldt, securityenddt)` | ✓ mechanism exactly as described |
| **Ex-ante screens** at formation (PR #330) | `filter_sorting_data.R`: new `rebalancing_month` arg; default `timing = "formation"` routes to `screen_at_formation()` (cohort `= year − (month < rebalancing_month)`, screens on formation rows, passing stocks kept for the holding period); `timing = "every_period"` calls `warn_every_period_screens()` | ✓ |
| **Fama-MacBeth** — remove the second √T, describe NW(1994), sort by date | `estimate_fama_macbeth.R`: iid SE `= sqrt(stats::vcov(model)[1,1])` of the `value ~ 1` regression (= SE of the mean), `t = mean/SE`; cross-sections `arrange()`d by date before aggregation; `vcov_options` doc states VAR(1) prewhitening + NW(1994) auto bandwidth | ✓ all three |
| FM unit test matches a one-sample *t*-test | `tests/testthat/test-estimate_fama_macbeth.R:431` compares `risk_premium`/`standard_error`/`t_statistic` to `stats::t.test()` on the per-date slopes | ✓ |
| **FF July timing** of `ff_adjustment` | `join_lagged_values.R::ff_windows()`: last obs per id-year, usable window `[Jul 1 of y+1, Jun 30 of y+2]`; `min_lag`/`max_lag` ignored with an informational message; works with `by` | ✓ |
| FF tests cover Dec and June year-ends | `tests/testthat/test-join_lagged_values.R:43` builds a "dec" (Dec 2020) and "jun" (Jun 2020) firm, asserts both update Jul 2021–Jun 2022 | ✓ |
| **Staggered rebalancing** `holding_period`/`skip` (PR #334) | `compute_portfolio_returns.R` (defaults `holding_period = 1L`, `skip = 0L`; incompatible with `rebalancing_month`) + `staggered_portfolios.R::compute_staggered_returns()`: cohorts over `[formation+skip, +holding_period−1]` joined to the **full** holding panel, overlapping cohorts averaged | ✓ JT(1993) mechanism; vignette has a 6-month example |
| Ex-ante screens under staggered rebalancing | `implement_portfolio_sort.R::screen_staggered_formation()`: screen-failing stocks get the sorting variable set to `NA` (excluded from the new cohort, kept in earlier cohorts) | ✓ |
| **NYSE 80th-pct cap** (Jensen 2023) + corrected dependent-sort size cutoff | `compute_portfolio_returns.R`: `cap_weight_exchanges = "NYSE"` default (all-stock fallback with a message); `main_min_mktcap()` computes the `breakpoints_min_size_threshold` cutoff on the full cross-section per date before the secondary grouping | ✓ |
| **WRDS setup** documented + connection errors rethrown with hints + progress/`quiet` | `get_wrds_connection.R`: `@section` checklist (institution subscription, Duo 2FA, accept terms, store credentials, approve push); `tryCatch` rethrows with those hints and redacts credentials; `cli_progress_step` gated by `quiet`; `wrds_download_step()` prints a timed step. Checklist also in `set_wrds_credentials.R`, `README.md`, `vignettes/tidyfinance.Rmd` | ✓ (both editor points) |
| **New data sources** FRED-MD/QD + Damodaran | `list_supported_datasets.R` + `download_data_fred_md()` / `download_data_damodaran()` | ✓ |
| Referee 2's six edits | manuscript: affiliation comma (`tidyfinance.Rmd:35`), `Freq.` column + legend in Table 2, `remotes::install_github` (`:143`), "single package" rewording (`:117`), Dickerson comma removed, orphan (render-dependent) | ✓ |

**Cosmetic note (not an error):** the letter cites PR **#316** and **#330** (correct PR numbers);
`NEWS.md` cites the matching *issue* numbers (#320, #321). A referee cross-referencing the two could be
briefly confused. No action required, but worth being aware of.

---

## 2. Points from the letters not yet fully closed

1. **Editor — "comply with the R Journal package guidelines."** Not acknowledged in the response
   letter. Add one sentence confirming compliance (ideally noting `R CMD check` / `urlchecker` pass).
2. **Referee 1, point 6 — full replication of JT (1993) Table I.** Explicitly *declined* with a
   page-budget + sample-period justification (`response-letter.md` comment 6). Defensible, but the editor
   must accept the scope reduction; keep the justification crisp.
3. **`prc_lag` default price column** (referee point 2's "make the previous month's nominal price the
   default"). Implemented in the package (`data_options()` default `price = "prc_lag"`) but **not
   mentioned** in the letter. Add a sentence so the referee sees it.
4. **Paper wording, finding N20.** `tidyfinance.Rmd:575` still states that `implement_portfolio_sort()`
   "returns the long-short factor return series alongside the underlying portfolio returns," but the
   function returns only portfolio returns; the case study calls `compute_long_short_returns()`
   separately (`:835`). The referee flagged exactly this. Quick wording fix.

---

## 3. Triage of the companion (optional recommendations 8–15 + minor points)

Only report points 1–7 are required. Everything in `CHECKLIST.md` under "Recommended" and "Minor" is
optional. Status is judged against `NEWS.md` and the current source; where marked "by design" the
behaviour is defensible and the referee asks mainly that it be documented.

### 3a. Already fixed as a byproduct of the must-fix PRs — just tick / mention in the letter
`H3` (NYSE cap), `H6` (FF timing), `H7` (ex-ante screens), `N5` (`prc_lag`), `N6` (per-date size
cutoff), `N1`/`N2` (Fama-MacBeth √T and row order), `N32` (`add_lagged_columns` `by`+`ff_adjustment`),
`N25` (index-constituents 404, PR #311).

### 3b. Cheap, high-goodwill package fixes — recommend doing
- `N3` — `compute_long_short_returns()` accepts any `direction` string; validate it.
- `N12` — option constructors swallow misspelled names via `...` (e.g. `exclude_finacials`); reject unknown names.
- `N11` — `compute_portfolio_returns()` message blames "insufficient observations" for the wrong cause.
- `N22` — `compute_long_short_returns()` breaks when given the same custom `data_options` as `compute_portfolio_returns()`.
- `N23` — `estimate_model()` returns the intercept t-statistic in an empty-named column.
- `N9` — `trim()` help says the vector gets shorter; it returns same-length NAs.
- `N18` — the breakpoint-offset test passes whether or not the offset exists; strengthen it.
- `C2`/`N13` — month-end dates: `date - months(1)` is NA on month-end panels. Floor to first-of-month or error.

### 3c. Document the convention rather than change the code (defensible design choices)
`H9`/`H1` (signal must be pre-lagged; tie direction), `C1` (breakpoints over surviving stocks),
`H5` (one missing return → NA portfolio), `H4` (bivariate cell averaging), `N7`/`N8`/`N28`
(missing-value handling in lags, holding months, earnings screen), `N26`/`N27` (pseudo-data realism and
RNG reset), `N14`/`N15`/`N16`/`N30`/`N31` (risk-free splice, download row order, CCM link timing,
book-equity deferred taxes), `H8b` (v1 legacy delisting — does not affect the v2-based paper).

### 3d. Features — defer or decline with a one-line cost-benefit note
- `F2` (portfolio turnover) and `F3` (constituent counts / characteristics) — already acknowledged in
  the related-work paragraph as PyBondLab strengths tidyfinance does not offer.
- `H10`/`D1` — `implement_portfolio_sorts()` (plural, many signals in one call) + WRDS download cache.
- `F4` — add the public OSBAP corporate-bond panels to `download_data()`.
- `U1` — an agent-oriented guide in `llms.txt`.

### 3e. Paper-text minor
- `N17` — `additional_columns = c("at", "ib")` is redundant (both are default columns); harmless, optional.
- `P5` — references: Akey et al. (2026) DOI, Welch–Goyal author order, unsourced "213+".
- `P6` — dead cross-reference ("Section 2.3.4"), footnote 1 claim.
- `P7` — the replication-repository URL returned HTTP 404 on 2026-10-05; confirm it resolves.
- `P9`/`P10` — optional citations: Menkveld et al. (2024) on nonstandard errors; Dickerson et al. (2026).

---

## 4. Recommendation

- **Verification result: pass.** Nothing in the response letter is unimplemented or implemented
  incorrectly. The package work is careful and matches the referee's own corrected computations (the
  rerun Table 7 slopes −0.0046 / t = −6.04 and −0.0011 / t = −2.49 match the referee's Table A2 "All"
  column within rounding).
- Close the four Section-2 gaps — they are nearly free and two were explicitly raised by the editor/referee.
- Adopt the §3b cheap package fixes to show good faith before a second round.
- Document the §3c conventions (a short help-page paragraph each) rather than change behaviour.
- Decline the §3d features with a one-line cost-benefit note; `F2`/`F3` are already positioned as
  PyBondLab's complementary strengths.

---

## 5. Change log

**2026-10-22 — the four §2 gaps drafted** (edits only; nothing committed or re-rendered):

1. **N20 wording** — `tidyfinance.Rmd` (Section 3 overview, the `implement_portfolio_sort()`
   paragraph): "returns the long-short factor return series alongside the underlying portfolio returns"
   → "returns the panel of portfolio returns; piping that result to `compute_long_short_returns()`
   yields the long-short factor series, as in the case study below." (prose only — no numbers change,
   but the rendered PDF is now stale and needs a re-render before submission.)
2. **R Journal package guidelines** — `response-letter.md`, Editor section: added the editor's
   guidelines comment and a response confirming the `rjtools` template, CRAN status, roxygen2/vignette
   documentation, 100% coverage, and a clean `R CMD check` on the three platforms. *Authors should
   confirm the platform/coverage claims still hold and spot-check guideline-specific items (title case,
   reference DOIs, `urlchecker`).*
3. **`prc_lag` default** — `response-letter.md`, Referee 1 point 2: added a bullet noting the default
   price column is now `prc_lag` and that the help page states when each screen applies; also fixed the
   typo "logc" → "logic".
4. **JT justification** — `response-letter.md`, Referee 1 point 6: tightened the rationale for not
   reprinting JT (1993) Table I into an explicit cost-benefit argument (page limit + differing
   universe/period), while keeping all factual statements.

The untracked `referee-process/response-letter.md` copy was re-synced to the canonical root
`response-letter.md` after the edits.

**2026-10-22 — R Journal guidelines reply refined.** After the editor supplied the guidelines link
(journal.r-project.org/submissions.html), the Editor-section paragraph in `response-letter.md` was
rewritten to map to the actual package-paper requirements (CRAN; VCS link in `DESCRIPTION`;
value-checking unit tests; documented functions with examples; workflow vignette; comparison with
competitors; reproducibility; `rjtools` template). Authors still to confirm: run the `rjtools` article
checks and verify the coverage / `R CMD check` claims.

**2026-10-22 — §3b cheap package fixes applied in `r-tidyfinance`** (working tree on `main`, not
committed; full test suite passes with 0 failures / errors / warnings / skips, 1629 tests).

| Finding | Change | File(s) |
|---|---|---|
| N9 | `trim()` help now says it sets the tails to `NA` and keeps length | `R/trim.R` |
| N23 | `estimate_model(output = "tstats")` names the intercept-only column `intercept` | `R/estimate_model.R` |
| N3 | `compute_long_short_returns()` validates `direction` | `R/compute_long_short_returns.R` |
| N22 | `compute_long_short_returns()` reads the canonical `ret_excess_*` columns (or any containing `data_options$ret_excess`); informative error if none | `R/compute_long_short_returns.R` |
| N11 | `compute_portfolio_returns()` empty-panel and missing-value messages now state the real cause | `R/compute_portfolio_returns.R` |
| N12 | `filter_options()`, `breakpoint_options()`, `data_options()` warn on a near-miss option name (edit distance 1); `...` kept for genuine custom options | `R/filter_options.R`, `R/breakpoint_options.R`, `R/data_options.R` |
| N18 | Replaced the tautological breakpoint-offset test with a real test of the tie rule (a value on a breakpoint joins the upper portfolio) | `tests/testthat/test-compute_breakpoints.R` |
| C2/N13 | **Documentation only** — help pages of `add_lagged_columns()` / `join_lagged_values()` now state that month/year lags need first-of-month dates. Behavioural fix deferred (see below). | `R/add_lagged_columns.R`, `R/join_lagged_values.R` |

New unit tests added for N9, N23, N3, N22, N11, N12; `NEWS.md` updated; `man/` regenerated (no export
changes). `DESCRIPTION` and three `_snaps/*.md` files that the tools rewrote were reverted (roxygen
version stamp and line endings only).

Decisions and caveats:

- **N12 is a near-match _warning_, not a hard error.** An existing test and `breakpoint_options()`'s own
  example rely on `...` extensibility, and the referee accepted "an error or a warning." A warning also
  does not catch typos more than one edit away, so it is a partial guard.
- **N18's companion test depends on finding H1** (a `ties=` argument), which is out of scope; the
  replacement instead pins the current tie behaviour so the test would fail if that behaviour changed.
- **C2/N13 behavioural fix deferred — rationale.** `add_lagged_columns()` also supports day-level lags,
  so unconditional month-flooring (or a hard error on non-first-of-month dates) would regress a
  legitimate daily-data + month-lag use. A correct fix needs an opt-in `period`/frequency argument and
  validation against the OSBAP bond panels — a deliberate change, recommended as its own task. The
  first-of-month convention is now documented, which is the zero-risk part.
- **Bonus finding (not in the batch).** `estimate_model(df, "y ~ 1")` errors when `df` has a single
  column, because `df[complete, ]` drops to a vector before `lm()`. Out of scope here; worth a separate
  one-line fix (`drop = FALSE`).
