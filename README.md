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
- A WRDS subscription for access to CRSP and Compustat data

### Setup

Install and activate the locked package environment:

```r
install.packages("renv")
renv::restore()
```

### Data

Raw CRSP and Compustat data are proprietary and cannot be redistributed. To download them, configure your WRDS credentials once:

```r
library(tidyfinance)
set_wrds_credentials()
```

Then run the scripts in order:

```bash
Rscript code/02_download_raw_data.R
Rscript code/03_sorting_variables_yearly.R   # (and monthly/quarterly variants)
Rscript code/04_sorting_variables_combination_lag.R
Rscript code/05_portfolio_sorts.R
Rscript code/06_analyze_diagnostics.R
```

Precomputed factor returns for all specifications are also available directly via the `tidyfinance` API without running the pipeline:

```r
library(tidyfinance)
download_data("tidyfinance", "factor_library", sorting_variable = "ag")
```

### Compiling the manuscript

With the data in place, render the PDF from the project root:

```bash
quarto render jss-manuscript.qmd
```

## Related resources

- R package: [tidy-finance/r-tidyfinance](https://github.com/tidy-finance/r-tidyfinance) on CRAN
- Python package: `py-tidyfinance`
- Interactive dashboard: [factors.tidy-finance.org](https://factors.tidy-finance.org)
- Tidy Finance textbook: [tidy-finance.org](https://tidy-finance.org)

## License

Code is released under the [MIT License](LICENSE).
