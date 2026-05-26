# A Transparent Financial Risk Factor Library

Replication code and manuscript for the paper "A Transparent Financial Risk Factor Library" by Christoph Frey, Christoph Scheuch, Stefan Voigt, and Patrick Weiss, submitted to the *Journal of Statistical Software*.

## Overview

This repository contains all code and the Quarto manuscript for a JSS paper introducing `tidyfinance`, an R package for reproducible financial risk factor construction. The package covers a large number of sorting variables across hundreds of precomputed specifications. Every construction choice (breakpoints, weighting scheme, lagging convention, sample filters) is documented and configurable. Precomputed factor returns are accessible via a programmatic API and an interactive dashboard at [factors.tidy-finance.org](https://factors.tidy-finance.org).

## Repository structure

```
.
├── jss-manuscript.qmd        # Main Quarto manuscript
├── jss-manuscript.pdf        # Compiled PDF
├── bibliography.bib          # BibTeX references
├── code/
│   ├── 01_define_portfolio_sorts_grid.R   # Define the full specification grid
│   ├── 02_download_raw_data.R             # Download CRSP and Compustat data
│   ├── 03_sorting_variables_monthly.R     # Construct monthly sorting variables
│   ├── 03_sorting_variables_quarterly.R   # Construct quarterly sorting variables
│   ├── 03_sorting_variables_yearly.R      # Construct annual sorting variables
│   ├── 04_sorting_variables_combination_lag.R  # Apply lag conventions
│   ├── 05_portfolio_sorts.R               # Run portfolio sorts across all specs
│   └── 06_analyze_diagnostics.R           # Compute diagnostics and Sharpe ratios
├── data/                     # Parquet files (not tracked in git; see Data below)
├── renv.lock                 # Locked R package versions
└── LICENSE                   # MIT License
```

## Reproducing the results

### Requirements

- R (version specified in `renv.lock`)
- A WRDS subscription for access to CRSP and Compustat data. Readers without WRDS access can still render the manuscript against synthetic data; see "Rendering without WRDS" below.

### Setup

Install and activate the locked package environment:

```r
install.packages("renv")
renv::restore()
```

### Data

Rendering the manuscript does not require running any factor-library construction code: the precomputed library is pulled from Hugging Face via `download_data()` at render time. Raw CRSP and Compustat data are proprietary and cannot be redistributed; manuscript chunks that consume them require an institutional WRDS subscription. Configure WRDS credentials once:

```r
library(tidyfinance)
set_wrds_credentials()
```

Precomputed factor returns for all specifications are available directly through the `tidyfinance` API:

```r
library(tidyfinance)
download_data("tidyfinance", "factor_library", sorting_variable = "ag")
```

### Compiling the manuscript

With the data in place, render the PDF from the project root. End-to-end render time is about 15 minutes on a laptop:

```bash
quarto render jss-manuscript.qmd
```

### Regenerating the factor library (audit path)

Reviewers who want to regenerate the published factor library from raw WRDS data — rather than consume the precomputed Hugging Face artefact — can run the construction pipeline directly. This path takes about 3 hours on a 64-core machine and is **not required** to reproduce the manuscript:

```bash
Rscript code/01_define_portfolio_sorts_grid.R
Rscript code/02_download_raw_data.R
Rscript code/03_sorting_variables_monthly.R
Rscript code/03_sorting_variables_quarterly.R
Rscript code/03_sorting_variables_yearly.R
Rscript code/04_sorting_variables_combination_lag.R
Rscript code/05_portfolio_sorts.R
Rscript code/06_analyze_diagnostics.R
```

### Rendering without WRDS

Readers without a WRDS subscription can render the manuscript against synthetic data of identical schema. Open `jss-manuscript.qmd`, find the `set-data-domain` chunk at the top of Section 4, and change

```r
data_domain <- "wrds"
```

to

```r
data_domain <- "pseudo"
```

Every chunk that downloads CRSP or Compustat then dispatches to the `domain = "pseudo"` path in `tidyfinance`, which generates schema-compatible synthetic data on demand. The workflow reproduces; the quantitative results do not (values are simulated). The `seed` and `n_assets` arguments to `download_data()` control the synthetic draws.

## Related resources

- R package: [tidy-finance/r-tidyfinance](https://github.com/tidy-finance/r-tidyfinance) on CRAN
- Python package: [tidy-finance/py-tidyfinance](https://github.com/tidy-finance/py-tidyfinance)
- Interactive dashboard: [factors.tidy-finance.org](https://factors.tidy-finance.org)
- Tidy Finance textbook: [tidy-finance.org](https://tidy-finance.org)

## License

Code is released under the [MIT License](LICENSE).
