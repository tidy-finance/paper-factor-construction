# Response to the editor and referees

We thank the editor and the referees for their careful reading and constructive comments. Below we reply to each comment in turn. Comments are quoted, followed by our response. Table numbers in our responses refer to the revised manuscript.

## Editor

> Just getting a WRDS account alone was not sufficient, I needed to enable 2FA and also accept terms and conditions. [...] You may like to document this somewhere -- it doesn't necessary have to be in the paper (or you may already do).

Thank you for pointing this out. We now document the WRDS account prerequisites in both the package and the paper:

- **Package.** The help pages `?get_wrds_connection` and `?set_wrds_credentials`, the package vignette, and the README now contain a WRDS account setup checklist. In addition, `get_wrds_connection()` now catches failed connection attempts and rethrows them with these hints instead of the raw database error.
- **Paper.** The WRDS paragraph in the data section now states that credentials alone do not suffice, that users must enroll in 2FA and accept the WRDS terms of use before the first connection, and refers readers to `?get_wrds_connection` for the full checklist.

> Downloading data can take a few minutes, but function doesn't provide any alert. Perhaps it will be useful to have some alert or spinner regarding this?

- **Package.** We added status messages to the WRDS downloads and a `quiet` parameter to optionally suppress them. 

> In addition, please ensure that your submission complies with our guidelines at https://rjournal.github.io/R_package_guidelines.html.

We have reviewed the submission against the R Journal guidelines for papers about R packages. `tidyfinance` is on CRAN; its `DESCRIPTION` links to the GitHub repository and issue tracker; every user-facing function is documented with explained arguments and runnable examples; the package ships a vignette that walks through a full workflow; and its unit tests verify output values (not only class or structure), with 100% coverage reported by Codecov. The manuscript motivates the package for a broad audience, positions it against existing R packages and factor-data releases (Section 2), and demonstrates its use and advantages in an end-to-end case study (Section 4). The article is prepared with the `rjtools` template and is fully reproducible from the accompanying code under `renv`, with a pseudo-data path for readers without a WRDS subscription.

**Additional change.** Since the submitted version (tidyfinance 0.8.0), the package has gained two data sources, which Table 2 now lists: the FRED-MD and FRED-QD macroeconomic panels of McCracken and Ng (2016, 2021) and Aswath Damodaran's cost of capital by industry and region.

**Length.** To stay within the journal's 20-page limit despite the new material (the momentum table, the sensitivity checks, and the new data sources), we shortened the manuscript on a few occasions: Table 2 now lists one-line `download_data()` arguments instead of full code examples, all tables use the body font size, and the figure heights are reduced smaller. We also removed the Dow Jones constituents and Yahoo Finance example, shortened the description of the Goyal and Welch (2008) predictors, condensed the description of the pseudo-data path, and cut passages that repeated the related work in the introduction, the summary, and the computational details.

## Referee 1

We thank the referee for the companion to the report. Its record-by-record findings, runnable examples, and tested code were very useful, and we drew on them throughout the revision. We address the seven required changes below and, at the end of this section, list the recommended changes from the supplement that we also adopted.

> **1.** [...] Keep delisting returns in the CRSP download.

The companion's example (record H8a) reproduced the dropped delisting months and pinpointed the cause, which we fixed in the package: 

- **Package.** `download_data_wrds_crsp()` with `version = "v2"` now keeps the month and the day that carry a stock's delisting return ([PR #316](https://github.com/tidy-finance/r-tidyfinance/pull/316)). CIZ includes the delisting return in `mthret` and `dlyret`, but `stksecurityinfohist` holds no active record after a stock's last trading day, so the common-stock filters were evaluated at month end (or on the delisting day) and dropped these observations. Their security information is now looked up on the last trading day (`securityenddt`).

> **2.** [...] Apply sample screens only when portfolios are formed.

The companion's examples (records H7 and N5) showed that the screens looked ahead and that the default price column did not exist in the CRSP v2 download. Following your recommendation, we make ex-ante screens the default and keep the ex-post option behind a warning, without taking a side in the nonstandard-errors debate: 

- **Package.** With annual rebalancing (`rebalancing_month`), `implement_portfolio_sort()` and `filter_sorting_data()` now apply the screens of `filter_options()` in the formation month only and keep every stock that passes them for the whole holding period (ex-ante screens). The previous behaviour is still available with `filter_options(timing = "every_period")` and issues a warning. `filter_sorting_data()` gains a `rebalancing_month` argument ([PR #330](https://github.com/tidy-finance/r-tidyfinance/pull/330)).
- **Package.** Following your suggestion, the default price column is now `prc_lag`, the nominal price at the end of the previous month, instead of `prc_adj`, which the default CRSP v2 download does not return (so the `min_stock_price` screen previously failed on downloaded data). The help page of `filter_sorting_data()` now states when each screen applies: in the formation month only under annual rebalancing, and in every month otherwise.

> **3.** [...] The note to Table 6 names Newey and West (1987), but the estimator is prewhitened with the bandwidth of Newey and West (1994). Fix. Rerun Table 6 with 0.9.0, remove the extra √T with a test, and describe the estimator correctly.

The companion isolated both errors with runnable examples (records N1 and N2). We corrected them in the package and the paper:

- **Package.** `estimate_fama_macbeth(vcov = "iid")` no longer multiplies the $t$-statistic by $\sqrt{T}$ a second time, and a new unit test checks that the `"iid"` risk premium, standard error, and $t$-statistic match a one-sample $t$-test on the time series of cross-sectional slopes. The documentation of `vcov_options` now states that the default uses `sandwich::NeweyWest()` with VAR(1) prewhitening and the automatic bandwidth of Newey and West (1994).
- **Paper.** The function overview (Table 1), the text of the asset pricing test section, and the note to Table 7 now describe the estimator as Newey and West (1987) standard errors with first-order VAR prewhitening and the Newey and West (1994) automatic bandwidth, as implemented in `sandwich::NeweyWest()` (Zeileis, 2004). We add both references.
- **Rerun.** Table 7 is recomputed with the current package version; see our response to comment 4.

> **4. Rerun Tables 4 to 6 with these fixes.** [...] Fix. Report Tables 4 to 6 with delisting returns and fix standard errors. If the screens move to formation (point 2), rerun the customized row of Table 5 with them. Show the once-a-year timing of point 5 and the NYSE cap of point 8 of the supplement as sensitivity checks.

Following the companion's combined-impact table (record C0), we reran the full case study with the development version of tidyfinance (0.9.0.9007), which `renv.lock` now pins, so the computational details report the version actually used. This version includes all corrections from your report: delisting months in the CRSP download, screens at formation, the corrected $t$-statistics of `estimate_fama_macbeth()`, the Fama-French July timing of `ff_adjustment`, and the NYSE-based cap with the corrected dependent-sort size cutoff. All numbers in the text are now computed inline from the results, so the text and tables cannot drift apart in future renders.

- **Tables 4, 5, and 7** (Tables 4 to 6 of the original submission) are reported with delisting returns and the corrected standard errors. The asset growth slope in Table 7 is now $-0.0046$ ($t = -6.04$) and the size slope $-0.0011$ ($t = -2.49$).
- **Screens at formation.** The customized row of Table 5 uses the new default, ex-ante screens: with annual rebalancing, the screens apply in the formation month only, so a stock that fails a screen later keeps its holding-month returns. The text now says so and notes that `filter_options(timing = "every_period")` restores per-month screens with a warning.
- **Sensitivity checks.** Table 5 has two additional rows, each a one-argument change to the baseline. A plain 7-to-18-month lag window instead of the Fama-French timing gives a value-weighted premium of 3.4% per year ($t = 2.31$), against 3.5% ($t = 2.32$) in the baseline. Capping at the 80th percentile of all stocks instead of NYSE stocks raises the capped value-weighted premium from 4.3% ($t = 3.45$) to 4.8% ($t = 4.08$). Table 5 now also reports capped value-weighted returns for all rows.

> **5. Correct the statements that the tables do not fully support.** [...]

We reran all tables with the current package version (see also our response to comment 4) and revised each statement against the new numbers.

- **Monotonicity (Table 4).** We no longer call the value-weighted means monotone. The text now says that mean returns decline from the lowest to the highest asset growth quintile under all three weighting schemes, monotonically for equal and capped value weights, and with nearly equal third and fourth quintiles for value weights.
- **Significance (Table 5).** We dropped "borderline" and "significant at conventional levels" and now report the $t$-statistics directly in the text. With the rerun, the baseline spread has $t = 2.32$, the size-controlled spread $t = 3.06$, and the customized spread $t = 1.89$, which we now describe as no longer significant at the 5% level.
- **Size.** We removed the claim that size masked the signal. The text now says that the size-controlled sort barely moves the premium (3.5% to 3.6% per year) but raises the $t$-statistic because the spread is less volatile. We also removed the attribution of the larger equal-weighted spread to a correlation with size; the text now only notes that the effect is stronger among the small stocks that equal weighting emphasizes.
- **Comparison with Cooper et al. (2008).** We no longer call our premium consistent with theirs. The text says that the sign matches, that our spread is considerably smaller than their decile spread of about 12.6% per year, and that their spread is based on deciles. For the Fama-MacBeth slope, we replaced "directly comparable" with a statement that dividing their slope by 12 gives only a rough monthly counterpart, because they regress annual returns and include additional controls. We removed the incorrect statement about past returns from the footnote.
- **Fama-French timing.** We changed the package so that `ff_adjustment = TRUE` implements the Fama and French (1993) convention: the accounting data of a fiscal year ending in calendar year $t$ are used from July of $t+1$ through June of $t+2$, whatever the month of the fiscal year-end, so every firm updates in July. `min_lag` and `max_lag` are ignored in this mode, and new tests cover December and June fiscal year-ends. The description of Figure 1 now matches the code. In the case study, we removed the `min_lag`/`max_lag` arguments and the "12-to-18-month window" text. With the corrected timing, the asset growth slope in Table 7 is $-0.0046$ ($t = -6.04$).
- **Jensen et al. (2023).** We now report 153 factors in 93 countries instead of "hundreds of signals across many countries" (Introduction, related work, and Table 2), and no longer describe them as spanning asset classes. The package's capped value weights now cap at the 80th percentile of NYSE stocks, as in Jensen et al. (2023), and the text and the note to Table 4 say so. We no longer cite Jensen et al. (2023) for NYSE breakpoints and cite Fama and French (1993) instead.

> **6. Offer staggered rebalancing, and replicate Jegadeesh and Titman (1993) as a second case study.** [...] Fix. Add holding_period, skip and rebalancing_frequency arguments (tested code in the companion), and a second case study that replicates Table I of Jegadeesh and Titman (1993).

This suggestion closes a real gap in the package.

- **Package.** `implement_portfolio_sort()` and `compute_portfolio_returns()` gain the arguments `holding_period` and `skip`. With `holding_period = K`, portfolios are formed every period, each cohort is held for $K$ periods starting `skip` periods after formation, and the returns of the overlapping cohorts are averaged as in Jegadeesh and Titman (1993). Screens apply at formation, so a stock stays in its earlier cohorts until their holding period ends. We did not add a separate `rebalancing_frequency` argument: monthly formation with `holding_period` and annual formation with `rebalancing_month` cover the cases in the paper. The package vignette contains a worked six-month momentum example.
- **Paper.** The capability you ask for—staggered rebalancing with overlapping cohorts, illustrated on the momentum strategy of Jegadeesh and Titman (1993)—is now in the package and in a new case-study subsection ("Staggered rebalancing", Table 6). Table 6 computes the six-month momentum signal on calendar months, lags it by one month, and sorts stocks into NYSE deciles with holding periods $K \in \{1, 3, 6, 12\}$, each a one-argument change; the $K = 6$ row is their 6/6 strategy. On the case-study sample (1972 to 2024, all exchanges), the equal-weighted winner-minus-loser spread rises from $-1.0\%$ per year ($t = -0.31$) with monthly rebalancing to 6.9% ($t = 2.51$) with six overlapping cohorts, and the value-weighted 6/6 spread is 8.8% ($t = 3.10$). We illustrate the overlapping-cohort mechanism of their Table I rather than reprinting the table itself: a full $J \times K$ grid would add a large second table against the journal's 20-page limit while re-sampling a different universe and period (NYSE and AMEX, 1965 to 1989, which predates most of our CRSP panel), so it would demonstrate the same one-argument machinery at a disproportionate cost to length. The compact illustration already shows how the holding period alone moves the premium. The paper also mentions staggered rebalancing in the function overview (Table 1) and the description of `compute_portfolio_returns()`, and in the comparison with PyBondLab.

> **7. Cite existing factor-construction software.** Problem. Pages 1 and 2 say that no widely adopted tool covers factor construction and that none of the existing projects exposes it as a callable API. PyBondLab (Rossetti and Dickerson, 2026), a Python package on PyPI since July 2024, does exactly this. [...] Fix. Cite it, and state how the two packages differ.

We had indeed overlooked PyBondLab. We now cite it (version 0.3.0) and have revised the text accordingly:

- **Introduction.** We qualify the claim to "no widely adopted tool covers this upstream workflow end to end" and add that PyBondLab exposes portfolio sorts for corporate bonds as a callable API but leaves data acquisition and cleaning to the user.
- **Related work.** We restrict the statement that no project exposes its pipeline as a callable API to the factor data releases, and add a new paragraph on factor-construction software. It states that PyBondLab, like tidyfinance, offers single and double sorts with staggered rebalancing. It credits PyBondLab with within-firm sorts, batched sorts on many signals, banding, and portfolio turnover, none of which tidyfinance offers. It then lists where tidyfinance differs: integrated data acquisition and cleaning from raw WRDS panels, equity-specific construction choices such as capped value weights and industry and earnings screens, and Fama-MacBeth regressions. We describe the two packages as complementary across asset classes and languages.

We also note that tidyfinance now supports staggered rebalancing with overlapping holding periods (arguments `holding_period` and `skip` of `implement_portfolio_sort()`), which we illustrate with Jegadeesh and Titman (1993) momentum in the new Table 6 (see our response to comment 6).

> **Recommended changes (supplement).** The supplement lists further changes you recommend but do not require.

Beyond the seven required changes, we adopted several of the companion's recommendations. We validate the `direction` argument of `compute_long_short_returns()` and let it accept the same `data_options` as `compute_portfolio_returns()` (records N3 and N22); the option constructors now warn on a misspelled option name (N12); `compute_portfolio_returns()` reports the actual cause of a missing or empty result instead of always citing insufficient observations (N11); we corrected the `trim()` documentation (N9) and the intercept-only $t$-statistic name in `estimate_model()` (N23, together with a related failure on a single-column data frame); we replaced a vacuous breakpoint test with one that checks the tie rule (N18); and we document that the lagging functions expect first-of-month dates for month-based lags (records C2 and N13). We leave the larger feature requests---portfolio turnover, batched multi-signal sorts, and the public corporate-bond panels---and the behavioural month-end-date change to future releases.

## Referee 2

> Pg 20, Stefan Voigt: Maybe add a linebreak, or comma, between U of C and DFI.

The two affiliations now appear separated by a comma: "University of Copenhagen, Danish Finance Institute".

> Pg 4, Sec 3, Table 2: Would the table be more legible if it had another column with 'D', 'W', 'M', 'Q', 'A' (or alike) for daily, weekly, monthly, quarterly, annual, ... data frequencies? In order to make the resolution more easily detectable?

Table 2 now has a "Freq." column that lists the available frequencies of each source (D, W, M, Q, A, and I for intraday data), with the legend in the table caption. We removed the frequency wording from the descriptions accordingly.

> Pg 3, Sec 3, Par 1: Why not remotes::install_github()? It is lighter than `pak` and works well enough.

The installation section now installs the development version with `remotes::install_github("tidy-finance/r-tidyfinance")`, and the computational details section cites `remotes` instead of `pak`.

> Pg 1, Sec 1, Par 4: 'a single dependency': really? Isn't that too narrow a view? I get 17 when looking at non-recursive strong dependencies via `length(tools::package_dependencies("tidyfinance", which="strong")[[1]])`

The phrase was indeed misleading. We meant that users add one package to their project, not that the package itself has no dependencies. The sentence now reads "the package supplies it as a single package that researchers can install, call, audit, and reuse". The 17 strong dependencies are mostly established infrastructure: tidyverse and r-lib packages for data manipulation and programming (`cli`, `dplyr`, `dbplyr`, `lifecycle`, `lubridate`, `purrr`, `rlang`, `slider`, `tibble`, `tidyr`, `httr2`), the database interface for WRDS (`DBI`, `RPostgres`), file parsers for the data providers (`jsonlite`, `nanoparquet`), and `stats` and `sandwich` for the estimation functions.

> Pg 1, Sec 1, Par 2: Remove comma before 'covers' in 'the Open Source Bond Asset Pricing project (Dickerson et, 2024), covers'

Done.

> Pg 9, just before Sec 4: Bad one-line LaTeX orphan. I supposed final editing will take care of that.

After the revision, the paragraph before Section 4 no longer ends in a one-line orphan. 
