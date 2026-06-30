---
output: pdf_document
---

\today

Dear Editors of The R Journal,

We are pleased to submit our manuscript, "tidyfinance: Transparent Factor
Construction for Empirical Asset Pricing," for consideration as a contributed
research article.

Empirical research in finance and the quantitative social sciences depends on a
data-preparation pipeline that is notoriously opaque: turning raw accounting and
return data into research-ready factor portfolios involves dozens of
consequential, undocumented choices, and results often cannot be reproduced. The
*tidyfinance* package, available on CRAN, makes this pipeline transparent and
reproducible. It exposes every construction decision as a configurable parameter
with a documented default, and provides a unified `download_data()` interface and
a set of small, composable functions for the steps in between. We illustrate the
workflow end to end by reproducing a well-known asset-pricing factor from raw
data. The manuscript focuses on the package's design and interface rather than on
asset-pricing methodology, which it covers only as far as needed to show what the
package does.

We believe the article fits The R Journal on three counts. First, it is a
reproducibility story for a large applied community: the package turns implicit,
hand-coded conventions into auditable, versioned, tested, and documented code,
ships a vignette that walks through the complete factor-construction workflow,
and already underpins open teaching materials used in graduate finance and
data-science courses. Second, although the package connects to the subscription
data (CRSP, Compustat via WRDS) that this field treats as standard, it equally
serves the free and open sources most R users can access — Ken French's Data
Library, FRED, and Yahoo Finance — and it ships a built-in pseudo-data generator,
so the package and this manuscript are fully runnable and reproducible without
any subscription. Third, it offers a capability existing R packages do not:
data-acquisition packages such as *frenchdata*, *quantmod*, and *tidyquant* stop
at raw downloads, and downstream analysis packages assume a clean panel already
in hand, whereas *tidyfinance* exposes the construction layer in between as
configurable, auditable code.

We confirm that this work is original, has not been published previously, and is
not under consideration for publication elsewhere. All code and data workflows
are publicly available, and the results in the manuscript are reproducible.

On behalf of all authors, thank you for considering our submission.

Sincerely,

Christoph Frey (Lancaster University)\
Christoph Scheuch (Humboldt University of Berlin)\
Stefan Voigt (University of Copenhagen and Danish Finance Institute)\
Patrick Weiss (Reykjavík University)
