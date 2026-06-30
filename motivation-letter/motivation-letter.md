---
output: pdf_document
---

\today

Dear Editors of The R Journal,

We are pleased to submit our manuscript, "tidyfinance: Transparent Factor
Construction for Empirical Asset Pricing," for consideration as a contributed
research article.

The manuscript introduces the [tidyfinance]{.pkg} package, available on CRAN,
which provides research infrastructure for the empirical asset pricing data
workflow: turning raw accounting and return data into factor portfolios for
asset pricing tests, portfolio allocation, and trading-strategy design. The
package exposes every construction decision as a configurable parameter with a
documented default. A unified `download_data()` interface harmonizes panels from
WRDS (CRSP, Compustat), Ken French's Data Library, FRED, and other providers,
and modular functions automate fiscal-year lagging, breakpoint computation, and
portfolio aggregation. We illustrate the package by reproducing the asset growth
factor of Cooper, Gulen, and Schill (2008) end to end from raw data.

We believe the article is a good fit for The R Journal: it presents a tested,
versioned, CRAN-released R package of broad interest to the large community of R
users in finance, economics, and the quantitative social sciences, and it
emphasizes software design and reproducibility over methodology alone. The
package fills a gap between data-acquisition packages and downstream analysis
packages by exposing the factor-construction pipeline itself as configurable,
auditable code.

We confirm that this work is original, has not been published previously, and is
not under consideration for publication elsewhere. All code and data workflows
are publicly available, and the results in the manuscript are reproducible.

On behalf of all authors, thank you for considering our submission. We look
forward to your feedback.

Sincerely,

Christoph Frey (Lancaster University)\
Christoph Scheuch (Humboldt University of Berlin)\
Stefan Voigt (University of Copenhagen and Danish Finance Institute)\
Patrick Weiss (Reykjavík University)
