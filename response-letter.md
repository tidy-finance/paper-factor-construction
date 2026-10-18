# Response to the editor and referees

We thank the handling editor and the referees for their careful reading and constructive comments. Below we reply to each comment in turn. Comments are quoted, followed by our response.

## Handling editor

> Just getting a WRDS account alone was not sufficient, I needed to enable 2FA and also accept terms and conditions. [...] You may like to document this somewhere -- it doesn't necessary have to be in the paper (or you may already do).

Thank you for pointing this out. We now document the WRDS account prerequisites in both the package and the paper:

- **Package.** The help pages `?get_wrds_connection` and `?set_wrds_credentials`, the package vignette, and the README now contain a WRDS account setup checklist: obtain an account, enroll in two-factor authentication (Duo), accept the WRDS terms of use on the WRDS website, store credentials with `set_wrds_credentials()`, and approve the Duo push notification when connecting. In addition, `get_wrds_connection()` now catches failed connection attempts and rethrows them with these hints instead of the raw database error.
- **Paper.** The WRDS paragraph in the data section now states that credentials alone do not suffice, that users must enroll in 2FA and accept the WRDS terms of use before the first connection, and refers readers to `?get_wrds_connection` for the full checklist.

## Referee 1

> **3.** [...] The note to Table 6 names Newey and West (1987), but the estimator is prewhitened with the bandwidth of Newey and West (1994). Fix. Rerun Table 6 with 0.9.0, remove the extra √T with a test, and describe the estimator correctly.

Thank you for catching both points.

- **Package.** `estimate_fama_macbeth(vcov = "iid")` no longer multiplies the $t$-statistic by $\sqrt{T}$ a second time, and a new unit test checks that the `"iid"` risk premium, standard error, and $t$-statistic match a one-sample $t$-test on the time series of cross-sectional slopes. The documentation of `vcov_options` now states that the default uses `sandwich::NeweyWest()` with VAR(1) prewhitening and the automatic bandwidth of Newey and West (1994).
- **Paper.** The function overview (Table 1), the text of the asset pricing test section, and the note to Table 6 now describe the estimator as Newey and West (1987) standard errors with first-order VAR prewhitening and the Newey and West (1994) automatic bandwidth, as implemented in `sandwich::NeweyWest()` (Zeileis, 2004). We add both references.
- **Rerun.** Table 6 is recomputed with the current package version; see our response to comment 4.

> **7. Cite existing factor-construction software.** Problem. Pages 1 and 2 say that no widely adopted tool covers factor construction and that none of the existing projects exposes it as a callable API. PyBondLab (Rossetti and Dickerson, 2026), a Python package on PyPI since July 2024, does exactly this. [...] Fix. Cite it, and state how the two packages differ.

Thank you for pointing us to PyBondLab, which we had overlooked. We now cite it (version 0.3.0) and have revised the text accordingly:

- **Introduction.** We qualify the claim to "no widely adopted tool covers this upstream workflow end to end" and add that PyBondLab exposes portfolio sorts for corporate bonds as a callable API but leaves data acquisition and cleaning to the user.
- **Related work.** We restrict the statement that no project exposes its pipeline as a callable API to the factor data releases, and add a new paragraph on factor-construction software. It states that PyBondLab, like tidyfinance, offers single and double sorts with staggered rebalancing. It credits PyBondLab with within-firm sorts, batched sorts on many signals, banding, and portfolio turnover, none of which tidyfinance offers. It then lists where tidyfinance differs: integrated data acquisition and cleaning from raw WRDS panels, equity-specific construction choices such as capped value weights and industry and earnings screens, and Fama-MacBeth regressions. We describe the two packages as complementary across asset classes and languages.

We also note that the development version of tidyfinance now supports staggered rebalancing with overlapping holding periods (arguments `holding_period` and `skip` of `implement_portfolio_sort()`), which we use in the new Jegadeesh and Titman (1993) case study (see our response to comment 6).

## Referee 2

> Pg 20, Stefan Voigt: Maybe add a linebreak, or comma, between U of C and DFI.

Thank you. The two affiliations now appear separated by a comma: "University of Copenhagen, Danish Finance Institute".

> Pg 4, Sec 3, Table 2: Would the table be more legible if it had another column with 'D', 'W', 'M', 'Q', 'A' (or alike) for daily, weekly, monthly, quarterly, annual, ... data frequencies? In order to make the resolution more easily detectable?

Thank you for this suggestion. Table 2 now has a "Freq." column that lists the available frequencies of each source (D, W, M, Q, A, and I for intraday data), with the legend in the table caption. We removed the frequency wording from the descriptions accordingly.

> Pg 3, Sec 3, Par 1: Why not remotes::install_github()? It is lighter than `pak` and works well enough.

We agree. The installation section now installs the development version with `remotes::install_github("tidy-finance/r-tidyfinance")`, and the computational details section cites `remotes` instead of `pak`.

> Pg 1, Sec 1, Par 4: 'a single dependency': really? Isn't that too narrow a view? I get 17 when looking at non-recursive strong dependencies via `length(tools::package_dependencies("tidyfinance", which="strong")[[1]])`

Thank you, the referee is right that the phrase was misleading. We meant that users add one package to their project, not that the package itself has no dependencies. The sentence now reads "the package supplies it as a single package that researchers can install, call, audit, and reuse". The 17 strong dependencies are mostly established infrastructure: tidyverse and r-lib packages for data manipulation and programming (`cli`, `dplyr`, `dbplyr`, `lifecycle`, `lubridate`, `purrr`, `rlang`, `slider`, `tibble`, `tidyr`, `httr2`), the database interface for WRDS (`DBI`, `RPostgres`), file parsers for the data providers (`jsonlite`, `nanoparquet`), and `stats` and `sandwich` for the estimation functions.

> Pg 1, Sec 1, Par 2: Remove comma before 'covers' in 'the Open Source Bond Asset Pricing project (Dickerson et, 2024), covers'

Done, thank you.
