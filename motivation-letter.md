---
output: pdf_document
---

\today

Dear Editors of The R Journal,

We are pleased to submit our manuscript, "tidyfinance: Transparent Factor
Construction for Empirical Asset Pricing," for consideration as a contributed
research article.

Empirical research in finance and the quantitative social sciences rests on
data-preparation pipelines that are notoriously opaque, so that published
findings often cannot be reproduced. The problem is especially acute in
empirical asset pricing, where turning raw accounting and return data into
research-ready factor portfolios requires dozens of consequential yet
undocumented choices. The *tidyfinance* package, available on CRAN, makes this
pipeline transparent and reproducible: it exposes every construction decision as
a configurable parameter with a documented default, wrapped in a unified
`download_data()` interface and a set of small, composable, pipe-friendly
functions for the steps in between. The manuscript focuses on the package's
design and interface rather than on asset-pricing methodology, which it covers
only as far as needed to show what the package does.

We believe the article is a good fit for The R Journal for three reasons.

First, it is a package-description article that goes well beyond the package
vignette. Where the vignette demonstrates the workflow, the manuscript sets out
the design rationale, makes the case for transparency in a pipeline the field
otherwise leaves implicit, and reproduces a well-known asset-pricing factor end
to end while *varying* construction choices to show how each one moves the
result. The package turns implicit, hand-coded conventions into auditable,
versioned, tested, and documented code, and already underpins open teaching
materials used in graduate finance and data-science courses.

Second, the contribution is as much about R software design as about finance,
and it fills a real gap in the R ecosystem. Data-acquisition packages such as
*frenchdata*, *quantmod*, and *tidyquant* stop at raw downloads, and downstream
analysis packages assume a clean panel already in hand; *tidyfinance* exposes the
construction layer in between. Its design as a single default call that reproduces
standard practice, while overriding any one choice takes a single argument, is
of interest to R users and developers beyond the asset pricing domain.

Third, the package is fully runnable without any paid subscription. Although it
connects to the commercial data (CRSP and Compustat via WRDS) that this field
treats as standard, it equally serves the free and open sources most R users can
access (Ken French's Data Library, FRED, and Yahoo Finance) and ships a
built-in pseudo-data generator. As a result, this manuscript compiles end to end
from a single R Markdown source, and a reader without WRDS access can rebuild
every number, table, and figure.

One point on which we would welcome the editors' guidance concerns how the
manuscript should be rendered. For the results reported here, we
compile the R Markdown source against the proprietary WRDS database (with
`data_domain <- "WRDS"` set in line 959 of `tidyfinance.Rmd`), which reproduces
every number exactly but requires a WRDS subscription. The same source also
compiles against the built-in pseudo-data generator (`data_domain <- "Pseudo
Data"`), which any reader can run without a subscription. It exercises the 
identical code paths and renders every table and figure, but the results it 
produces are noise. We are happy to submit either version and would appreciate 
the editors' preference on which route best fits The R Journal's reproducibility 
standards.

The package is on CRAN, with fully documented and exported functions, examples,
unit tests, and a vignette. We confirm that this work is original, has not been
published previously, and is not under consideration for publication elsewhere.
All code and data workflows are publicly available, and the results in the
manuscript are reproducible.

On behalf of all authors, thank you for considering our submission.

Sincerely,

Christoph Frey (Lancaster University)\
Christoph Scheuch (Humboldt University of Berlin)\
Stefan Voigt (University of Copenhagen and Danish Finance Institute)\
Patrick Weiss (Reykjavík University)
