# JSS Submission Conformity Checklist

A working checklist for getting this repository (manuscript + replication code) into compliance with the *Journal of Statistical Software* (JSS) submission guide, style guide, BibTeX guide, and replication-material policy.

Source documents distilled below:

- Submission Guide — https://www.jstatsoft.org/guides/submission
- Information for Authors — https://www.jstatsoft.org/authors
- Style Guide — https://www.jstatsoft.org/style
- About / Submissions — https://www.jstatsoft.org/about/submissions
- JSS Quarto template (canonical example) — https://github.com/quarto-journals/jss

Legend: `[x]` already satisfied, `[ ]` open, `[~]` partially satisfied / needs verification.

---

## 1. Submission mechanics

- [ ] **1.1 Corresponding author is registered** at jstatsoft.org and will perform the submission.
- [x] **1.2 Manuscript is a PDF** (only PDF can be submitted) — `jss-manuscript.pdf` is built.
- [x] **1.3 LaTeX/JSS class** used for typesetting — Quarto `jss-pdf` format via `_extensions/quarto-journals/jss`.
- [ ] **1.4 No author fees**, no subscription — informational; no action.
- [ ] **1.5 Submission category** chosen. JSS publishes:
    1. **Scholarly articles** describing statistical software (peer-reviewed).
    2. **Code snippets** — smaller code projects (peer-reviewed).
    3. **Special issues** (by invitation, peer-reviewed; suggestions welcome).
    4. **Book reviews** (by invitation; suggestions welcome).
    5. **Reviews/comparisons of closed-source statistical software** (by invitation).

    For this paper: **scholarly article**. Confirm at submission.
- [ ] **1.6 Three attachments / links required** at submission:
    1. PDF manuscript in JSS style.
    2. Source code for the software.
    3. Replication materials for all results (preferably a standalone replication script).
- [ ] **1.7 Upload size limit is 50 MB per file.** Larger supplementary files must be hosted externally with an in-repo `README` describing how to download them; if no external server is available, contact `editor@jstatsoft.org`. Currently the repo ships well under 50 MB; check the eventual submission ZIP.
- [ ] **1.8 Be prepared for revisions:** every revision submission must include a **point-by-point reply** to reviewers/editors. Revision window is 6 months; conditional-accept window is 12 months. Plan the calendar.

## 2. Manuscript structure (Submission Guide + Style Guide)

The Submission Guide says: *"The typical JSS paper will have a section explaining the statistical technique, a section explaining the code, a section with the actual code, and a section with examples. Special emphasis is given to a careful review of existing implementations and a discussion of the advantages and disadvantages of the contribution in comparison to other solutions."*

The Style Guide / Quarto template `template.qmd` operationalises this as:

1. Introduction — embed methods **and software** in the literature, discuss competing & complementary software with explicit advantages/disadvantages.
2. Models and software — the technique + the implementation.
3. Illustrations / Application — actual code and worked examples.
4. Summary and discussion.
5. Computational details *(unnumbered)*.
6. Acknowledgments *(unnumbered; American spelling, no "e")*.
7. References *(unnumbered)*.
8. Appendices *(unnumbered, each with a real title — not "Appendix")*.

The manuscript should be **accessible to a broad community of practitioners, teachers, and researchers** — not just specialists. Re-read with that audience in mind.

Length: no hard limit, but **manuscripts longer than 30 pages typically incur much longer review times**. Current PDF length should be checked; if approaching 30 pages, move material to the appendix or supplementary.

Current state:

- [x] Introduction (`jss-manuscript.qmd:87`)
- [x] Background and related work (`:99`) — methods/software literature embedding lives here and is fine.
- [x] Package overview (`:111`) — plays the role of "Models and software".
- [x] Case study + Factor library (`:947`, `:1476`) — illustrations.
- [x] Summary (`:1655`).
- [x] Computational details, unnumbered (`:1663`).
- [x] Acknowledgments, unnumbered, AE spelling (`:1687`).
- [x] References, unnumbered (`:1691`).
- [x] Appendix has a real title ("Variable construction", `:1710`) rather than just "Appendix".
- [ ] **2.1** Consider renaming "Package overview" to something closer to JSS's expected "Models and software" / "Methods and implementation" — purely cosmetic, but reviewers expect that label.
- [ ] **2.2** Verify all section titles are in **sentence case** (only first word + proper nouns capitalised). Spot-check: current headings look compliant; re-read once more before submission.

## 3. Author block

JSS expects each author with full affiliation: department, address, city, country, postal-code, email, ORCID, and URL where available (see template `template.qmd:7-22`).

- [x] Name, affiliation, ORCID, email present for all four authors.
- [ ] **3.1** Add **department**, **street address**, **city**, **country**, **postal code** to each author entry — currently only a single-line affiliation string. The JSS class renders the full block in the title footer.
- [ ] **3.2** Add author URLs where authors have a personal/academic homepage.
- [ ] **3.3** Designate the corresponding author explicitly.

## 4. Abstract & keywords

- [x] Abstract present (single paragraph, no citations).
- [x] `keywords` and `keywords-formatted` (with `[R]{.proglang}` markup) both supplied.
- [ ] **4.1** Keywords should be lower-case, comma-separated, not capitalised (template note at `template.qmd:31`). Current list passes; double-check before submission.
- [ ] **4.2** Abstract must contain no citations and no undefined acronyms. Spot-check passes; re-read.

## 5. Markup conventions (Style Guide §2)

JSS-specific inline markup, used in body **and titles and references**:

- `[R]{.proglang}` — programming languages and large programmable systems.
- `[tidyfinance]{.pkg}` — package / software.
- `` `code` `` — function names, arguments, commands.
- `[foo]{.fct}` — function names where the function is the subject (template uses this in places).
- `[lm]{.class}` — S/R class names.

- [x] Pervasive `.proglang` / `.pkg` / inline-code markup throughout the manuscript and abstract.
- [ ] **5.1** Sweep through manuscript: every mention of `R`, `Python`, `Stata`, etc. should be `[R]{.proglang}` etc. Spot search:
  ```
  grep -nE '\b(R|Python|Stata|Julia|S)\b' jss-manuscript.qmd | grep -v '\.proglang'
  ```
- [ ] **5.2** Use `[fname]{.fct}` for function names that are the *subject* of a sentence (e.g., "[glm]{.fct} fits..."). Inline back-tick `` `glm()` `` is used elsewhere — currently the manuscript only uses back-ticks. Decide and standardise.
- [ ] **5.3** All package names anywhere in the manuscript wrapped in `[pkg]{.pkg}`. Run:
  ```
  grep -nE '\b(dplyr|tidyr|ggplot2|lubridate|arrow|knitr|MASS|stats)\b' jss-manuscript.qmd | grep -v '\.pkg'
  ```

## 6. Typography & terminology (Style Guide)

- [ ] **6.1** **Always** write `$p$~value`, `$t$~statistic`, `$F$~test`, etc. — no hyphen, with a tied non-breaking space (`~`). Current manuscript uses hyphen at e.g. `jss-manuscript.qmd:1277` (`$t$-statistic`). Fix all occurrences:
  ```
  grep -nE '\$[ptFz]\$-(value|statistic|test|score)' jss-manuscript.qmd
  ```
- [ ] **6.2** **Never** call a subsection "Subsection x.y" — always "Section x.y". Line `jss-manuscript.qmd:331` says *"described in the next subsection"* — rewrite to *"described in Section 3.2"* (or `@sec-variable-construction`).
- [ ] **6.3** Abbreviations: introduce on first use with expansion (lowercase expansion), thereafter use the acronym only. Examples: GLM, ML, IWLS, OLS, EW, VW, VWC, L/S, BIC, FF — verify each is expanded on first use.
- [ ] **6.4** American English throughout, including "Acknowledgments" (no "e"). Current manuscript spells correctly. Watch for "harmonise/standardise" → JSS prefers AE "harmonize/standardize". Sweep:
  ```
  grep -nE 'harmonise|standardise|capitalis(e|ed)|recognise|colour' jss-manuscript.qmd
  ```
- [ ] **6.5** No brackets-within-brackets in citations: never `(\cite{foo})`. Quarto's `[@foo]` is fine; watch hand-written cases like `[@dickerson.2023, [openbondassetpricing.com](...)]` at `:91` — the nested `[]` may render badly in JSS LaTeX.
- [ ] **6.6** Captions in **sentence style**, end with a period, no `\emph`/`\bf`/`\it`. Most current `fig-cap` / `tbl-cap` look fine; verify the periods.

## 7. Code chunks in the manuscript

- [ ] **7.1** Add `#| prompt: true` to every executable R chunk that shows input — produces JSS's required `R> ` prompt with `+  ` continuation. Currently no chunk sets this.
- [ ] **7.2** Spaces around operators: write `y = a + b * x`, never `y=a+b*x`. Sweep code chunks.
- [ ] **7.3** **First argument of `library()` and `data()` must be quoted** (style guide R-specific rule): `library("dplyr")`, `data("quine", package = "MASS")`. **All seven** `code/*.R` scripts currently use unquoted `library(dplyr)` etc. Fix:
  ```
  grep -nE 'library\([a-zA-Z]' code/*.R jss-manuscript.qmd
  ```
- [ ] **7.4** No empty line directly before or after a code chunk.
- [ ] **7.5** Avoid comments inside code chunks shown in the paper — move explanation to the LaTeX text (this rule is for in-paper chunks, not external replication scripts).
- [ ] **7.6** Continuation lines indented by exactly two spaces.
- [ ] **7.7** Keep lines short enough that printed code does not overrun the JSS column (~ 75 chars). Run the rendered PDF check.

## 8. Tables and figures

- [x] All tables/figures referenced via `@tbl-` / `@fig-` (Quarto crossrefs).
- [ ] **8.1** Captions placed *below* table/figure (JSS style). Quarto puts table captions below by default; manually confirm in PDF.
- [ ] **8.2** No vertical lines in tables. Spot the LaTeX-raw blocks for vertical rules.
- [ ] **8.3** Column headers in sentence style.
- [ ] **8.4** Tables floated to the top of the page (`[t!]`); Quarto-generated tables generally do this, verify.
- [ ] **8.5** Graphics should be vector (PDF) where possible; PNG only for raster content (Style Guide FAQ "Graphics formatting"). Mermaid diagram at `:144` renders to SVG/PDF via Quarto — confirm.
- [ ] **8.6** Cross-references say "Figure 3" / "Table 2" — never "Fig." or "Tab." abbreviations.

## 9. Bibliography (`bibliography.bib`)

Required JSS BibTeX conventions (Style Guide §3 and template `template.qmd:222-242`):

- [ ] **9.1** Every package / software cited has a BibTeX entry. Use `citation("pkg")` as a starting point for each R package.
- [ ] **9.2** Titles in **title case** (e.g., "A Grammar of Data Manipulation", not "A grammar of data manipulation"). Most current entries are OK; sweep:
  ```
  grep -nE 'title *=' bibliography.bib
  ```
- [ ] **9.3** **JSS markup in bib titles**: package names in titles must use `\pkg{...}`, languages `\proglang{...}`, code `\code{...}`. Currently **0 of 120** entries contain `\pkg{}` / `\proglang{}` / `\code{}`. Required for every R-package entry and any title that names a package or language. Example to fix:
  ```bibtex
  title = {\pkg{tidyquant}: Tidy Quantitative Financial Analysis},
  title = {\pkg{dplyr}: A Grammar of Data Manipulation},
  title = {Dates and Times Made Easy with \pkg{lubridate}},
  ```
- [ ] **9.4** Journal titles **fully spelled out, not abbreviated**, and in title case. Current entries look full ("Journal of Financial Economics", "The Review of Financial Studies"). Verify no "JFE" / "RFS" / "J. Finance".
- [ ] **9.5** **DOIs included where available**. Only ~10/120 entries have a DOI. Most journal articles since 2000 have DOIs on Crossref — bulk-add.
- [ ] **9.6** No URLs in entries where a DOI exists (DOI replaces the URL).
- [ ] **9.7** Author lists complete; no "et al." or `{others}`.
- [ ] **9.8** Years are four digits; book entries have publisher and location.
- [ ] **9.9** Consistent key style (`author.year` — already followed).
- [ ] **9.10** SSRN-only entries ("Available at SSRN") — replace with the published version where it has since appeared in a journal.

## 10. Replication materials (Submission Guide)

- [x] **10.1** Standalone replication scripts present in `code/01_*.R` … `code/06_*.R`, numbered, in run order.
- [x] **10.2** Dependency lock: `renv.lock` pinning R and package versions.
- [x] **10.3** Plain-text/ASCII source code, with comments.
- [x] **10.4** Output paths documented (parquet under `data/`).
- [ ] **10.5** **Reproducibility on at least one platform**, with platform listed. Add OS + R version + hardware to "Computational details" (currently lists package versions only).
- [ ] **10.6** **Cross-platform reproducibility** is the ideal. If something is platform-dependent (e.g., parallel backend, WRDS connector behaviour, locale-dependent sorting), **discuss the limitation explicitly** in the submission cover note and in `Computational details`.
- [ ] **10.7** **Initialise random number generators.** Any chunk that does sampling, bootstrap, simulation, or Monte Carlo needs an explicit `set.seed(...)` (or equivalent for `future`/`parallel` backends — see `future::nextRNGStream`). Sweep the manuscript chunks and the `code/` scripts for any non-deterministic operations.
- [~] **10.8** **"Reasonable time on a regular PC"** rule. Manuscript states ~15 min for the paper and ~3 h on a 64-core machine for the full library. The 3-hour pipeline exceeds the JSS expectation. Either:
  - provide a smaller "quick-replication" path that reproduces every figure/table within roughly an hour, **or**
  - explicitly justify the runtime in the platform-dependency note and ship pre-computed intermediate `data/` artefacts that any reviewer can drop in to skip the expensive stage.
- [x] **10.9** Reproducibility scope: every figure, table, and statistic in the manuscript must be regeneratable. The Quarto chunks driving `format(nrow(...))` and the alpha-distribution histograms tie into the parquet inputs — confirm each figure/table in the PDF maps to a chunk and an input dataset.
- [ ] **10.10** Distinguish "obtain raw data from WRDS" (proprietary, manual step, in `02_download_raw_data.R`) from "reproduce the paper from intermediates" (free, automatic). The README needs a short "minimal replication" section for the second path.
- [ ] **10.11** Reproduction script for the manuscript itself: a one-liner (`quarto render jss-manuscript.qmd`) is sufficient; document it.
- [ ] **10.12** Verify the rendered PDF on a clean machine before submission.
- [ ] **10.13** Bundle the **source code as an R package** if at all possible. JSS's R-specific recommendation: *"For R packages, we encourage inclusion of JSS submissions as vignettes of CRAN packages."* `tidyfinance` is already on CRAN; ideally the final manuscript ships as a vignette in the package (`vignettes/jss.Rnw` or `.Rmd`/`.qmd`) so users can do `vignette("jss", package = "tidyfinance")`. Decide whether to also ship the manuscript as a package vignette.

## 11. Code license

- [x] **11.1** A `LICENSE` file is present.
- [~] **11.2** JSS requires GPL-2 / GPL-3 or a GPL-compatible licence. The repo uses **MIT**, which **is** GPL-compatible (the manuscript notes this in §Computational details). Acceptable; flag to the editor at submission if asked.
- [ ] **11.3** Confirm each code file carries a header pointing to LICENSE (recommended, not strictly required).
- [ ] **11.4** The R package `tidyfinance` (if bundled) must itself ship under a GPL-compatible licence — already MIT on CRAN. Confirm at submission.

## 11b. Software packaging (Submission Guide — Software Preparation)

JSS's R/S/Stata-style guidance: *"For software environments with package/library systems, the code should come with formatted help files and should be packaged for easy installation. If at all possible, submitted software should also be available from a standard repository."*

- [x] **11b.1** `tidyfinance` is on CRAN — standard repository requirement met.
- [x] **11b.2** Formatted help files: package documentation builds via roxygen / Rd; confirm `?download_data` etc. exist in the released CRAN version.
- [ ] **11b.3** Decide whether to ship the JSS manuscript as a **CRAN vignette** of `tidyfinance` (encouraged for R packages).
- [ ] **11b.4** If any non-R code is used (C++, Java, etc.), package it with build instructions; JSS notes non-mainstream languages incur longer review times.

## 12. Data

- [x] **12.1** Proprietary data (CRSP, Compustat from WRDS) explicitly identified as non-redistributable, with instructions to acquire (`README.md` §Data).
- [x] **12.2** Public/derived data can be regenerated via `tidyfinance::download_data("tidyfinance", "factor_library")`.
- [ ] **12.3** State the **exact data vintage** used to compile the submitted version (CRSP / Compustat / FRED snapshot dates) in Computational details, so future reviewers can pin the dataset.
- [ ] **12.4** Provide the small derived parquet files needed to render the manuscript (`data/sorting_variable_information.parquet`, `data/portfolio_sort_grid.parquet`) either checked in or downloadable — currently `data/` is untracked, so the YAML inline `arrow::read_parquet(...)` calls in the abstract will fail for a fresh reviewer.

## 13. Repository hygiene

- [x] **13.1** README explains scope, install, run order.
- [x] **13.2** `.gitignore` and `renv/` set up.
- [x] **13.3** `code/` numbered and ordered.
- [ ] **13.4** Remove or document the unused script `code/06_analyze_variables.R` (parallel to `06_analyze_diagnostics.R` — README lists only the latter).
- [ ] **13.5** Ensure all files referenced from the manuscript (`data/*.parquet`, figures) either exist in the repo or are produced by an enumerated script.
- [ ] **13.6** Add a `CITATION` file or `inst/CITATION` line for users citing the manuscript.
- [ ] **13.7** Single top-level `README.md` for the replication package itself (already present); JSS reviewers read this first.

## 14. Pre-submission self-audit

- [ ] **14.1** Build the PDF on a fresh clone: `renv::restore(); quarto render jss-manuscript.qmd`.
- [ ] **14.2** Read the rendered PDF cover-to-cover; verify every figure/table renders, every reference resolves, every code listing is properly prompted and indented.
- [ ] **14.3** Run a spell-checker in American English.
- [ ] **14.4** Run `grep` sweeps in items 5.1, 5.3, 6.1, 6.4, 7.3 above and resolve every hit.
- [ ] **14.5** Tag a `submission-v1` git tag once the PDF is finalised so reviewers can reference the exact snapshot.

---

### Concrete open issues found in this audit

The items below were observed in the current tree and are the most actionable fixes:

| # | File / location | Issue | Fix |
|---|---|---|---|
| A | `code/02_download_raw_data.R:1-4` and all other `code/*.R` | `library(dplyr)` etc. unquoted | `library("dplyr")` — JSS R rule |
| B | `jss-manuscript.qmd:331` | "described in the next subsection" | "described in Section 3.2" or `@sec-variable-construction` |
| C | `jss-manuscript.qmd:1277` | `$t$-statistic` (hyphen) | `$t$~statistic` (no hyphen, nbsp) |
| D | `bibliography.bib` (whole file) | No `\pkg{}` / `\proglang{}` markup in titles | Wrap package and language names in package/language titles |
| E | `bibliography.bib` (whole file) | ~110/120 entries missing DOI | Add DOIs from Crossref |
| F | YAML front-matter `author:` | Affiliations lack department/address/city/country/postal | Use nested affiliation block per `template.qmd:7-22` |
| G | All in-paper R chunks | No `R>` prompt | Add `#\| prompt: true` |
| H | `data/` directory | Not tracked; manuscript YAML reads parquet files at render-time | Ship the small summary parquet files or document the bootstrap step |
| I | Replication runtime | Full pipeline ≈ 3 h on 64 cores | Provide a fast path (intermediates) or justify in submission note |
| J | `code/06_analyze_variables.R` | Not listed in README | Document or delete |
| K | Any RNG-dependent chunk | No visible `set.seed()` | Audit chunks; add seeds for simulation/bootstrap/parallel RNG |
| L | Manuscript packaging | Not bundled as a `tidyfinance` CRAN vignette | Consider shipping as `vignettes/jss-manuscript.qmd` in the CRAN package |
| M | Submission ZIP | 50 MB cap | Verify final submission bundle size; host large supplements externally if needed |
