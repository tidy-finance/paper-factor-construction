# Response to the editor and referees

We thank the handling editor and the referees for their careful reading and constructive comments. Below we reply to each comment in turn. Comments are quoted, followed by our response.

## Handling editor

> Just getting a WRDS account alone was not sufficient, I needed to enable 2FA and also accept terms and conditions. [...] You may like to document this somewhere -- it doesn't necessary have to be in the paper (or you may already do).

Thank you for pointing this out. We now document the WRDS account prerequisites in both the package and the paper:

- **Package.** The help pages `?get_wrds_connection` and `?set_wrds_credentials`, the package vignette, and the README now contain a WRDS account setup checklist: obtain an account, enroll in two-factor authentication (Duo), accept the WRDS terms of use on the WRDS website, store credentials with `set_wrds_credentials()`, and approve the Duo push notification when connecting. In addition, `get_wrds_connection()` now catches failed connection attempts and rethrows them with these hints instead of the raw database error.
- **Paper.** The WRDS paragraph in the data section now states that credentials alone do not suffice, that users must enroll in 2FA and accept the WRDS terms of use before the first connection, and refers readers to `?get_wrds_connection` for the full checklist.

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
