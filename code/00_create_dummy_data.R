# Dummy data to replace WRDS access in jss-manuscript.qmd
# -----------------------------------------------------------------------------
# The worked example in jss-manuscript.qmd downloads two proprietary WRDS panels
# (see the `download-crsp` and `download-compustat` chunks):
#
#   crsp_monthly <- download_data(
#     domain = "wrds", dataset = "crsp_monthly", version = "v2",
#     start_date = date_start, end_date = date_end, add_ccm_links = TRUE
#   )
#
#   compustat_annual <- download_data(
#     domain = "wrds", dataset = "compustat_annual",
#     start_date = date_start, end_date = date_end,
#     additional_columns = c("at", "ib"), only_usd = TRUE
#   ) |>
#     select(gvkey, date, at, ib)
#
# Readers without a WRDS subscription cannot run those calls. This script
# generates hypothetical `crsp_monthly` and `compustat_annual` objects with the
# same columns and conventions the manuscript relies on, so the entire worked
# example (summary statistics, lagging, univariate/bivariate sorts, and the
# Fama-MacBeth regression) renders end-to-end without WRDS.
#
# The data is *dummy*: it contains no samples of the original CRSP or Compustat
# data and is not meaningful. We merely draw random numbers, calibrating only
# the industry/exchange mix so that exchange- and SIC-based filters behave
# sensibly. The resulting numbers in the manuscript will be nonsensical.
#
# Only WRDS sources are faked here. Ken French factors used elsewhere in the
# manuscript (`download_data(domain = "factors_ff", ...)`) are public and
# downloaded as usual.
#
# Usage:
#   1. Run this script once to write data/crsp_monthly.parquet and
#      data/compustat_annual.parquet (it also leaves both objects in the
#      session, so it can be sourced directly).
#   2. In jss-manuscript.qmd, replace the two WRDS download chunks above with
#        crsp_monthly <- arrow::read_parquet("data/crsp_monthly.parquet")
#        compustat_annual <- arrow::read_parquet("data/compustat_annual.parquet")
#      (or `source("code/00_create_dummy_data.R")`), then render as normal.
# -----------------------------------------------------------------------------

library("dplyr")
library("tidyr")
library("lubridate")
library("arrow")

set.seed(1234)

# Match the manuscript's sample window (`set-date-range` chunk).
date_start <- as.Date("1972-01-01")
date_end <- as.Date("2024-12-31")

# A larger cross-section than the textbook dummy data (100 stocks): the
# manuscript forms NYSE-breakpoint quintiles and 5x2 dependent double sorts with
# a minimum of 10 stocks per portfolio, so enough constituents must survive the
# universe filters each month.
number_of_stocks <- 500

time_series_years <- seq(year(date_start), year(date_end), 1)
time_series_months <- seq(date_start, date_end, "1 month")

# Empirical industry and exchange frequencies of the real CRSP universe (from
# the Tidy Finance dummy-data blog post). Only the *mix* is calibrated; the
# identifiers and their industry/exchange assignments are fictional.
industries <- tibble(
  industry = c(
    "Agriculture", "Construction", "Finance", "Manufacturing", "Mining",
    "Public", "Retail", "Services", "Transportation", "Utilities", "Wholesale"
  ),
  prob = c(
    0.00319, 0.0113, 0.185, 0.339, 0.0508, 0.0779, 0.0620, 0.169, 0.0493,
    0.0180, 0.0357
  )
)

exchanges <- tibble(
  exchange = c("AMEX", "NASDAQ", "NYSE"),
  prob = c(0.113, 0.671, 0.216)
)

# Cross-section of fictional securities. `gvkey` is shared between the CRSP and
# Compustat panels (as CRSP-Compustat links would provide via add_ccm_links),
# so join_lagged_values(id_keys = "gvkey") in the manuscript finds matches.
stock_identifiers <- tibble(
  permno = seq_len(number_of_stocks),
  permco = seq_len(number_of_stocks),
  gvkey = sprintf("%06d", permno + 10000L),
  exchange = sample(
    exchanges$exchange, number_of_stocks, replace = TRUE, prob = exchanges$prob
  ),
  industry = sample(
    industries$industry, number_of_stocks, replace = TRUE,
    prob = industries$prob
  )
) |>
  mutate(
    # SIC code drawn from the range conventionally associated with the industry
    # so that exclude_financials (6000-6799) and exclude_utilities (4900-4999)
    # drop the intended firms.
    siccd = case_when(
      industry == "Agriculture" ~ sample(1:999, n(), replace = TRUE),
      industry == "Mining" ~ sample(1000:1499, n(), replace = TRUE),
      industry == "Construction" ~ sample(1500:1799, n(), replace = TRUE),
      industry == "Manufacturing" ~ sample(1800:3999, n(), replace = TRUE),
      industry == "Transportation" ~ sample(4000:4899, n(), replace = TRUE),
      industry == "Utilities" ~ sample(4900:4999, n(), replace = TRUE),
      industry == "Wholesale" ~ sample(5000:5199, n(), replace = TRUE),
      industry == "Retail" ~ sample(5200:5999, n(), replace = TRUE),
      industry == "Finance" ~ sample(6000:6799, n(), replace = TRUE),
      industry == "Services" ~ sample(7000:8999, n(), replace = TRUE),
      industry == "Public" ~ sample(9000:9999, n(), replace = TRUE)
    )
  )

# crsp_monthly -----------------------------------------------------------------
# Mirrors the cleaned CRSP 2.0 monthly panel returned by download_data():
# month-end `date`, market cap in million USD, a one-month lag of market cap for
# portfolio weights, and excess returns net of the risk-free rate. The
# manuscript consumes permno, gvkey, date, ret_excess, exchange, siccd, and
# mktcap_lag; the remaining columns are included for fidelity to the real panel.
crsp_monthly <- expand_grid(
  stock_identifiers,
  tibble(month = time_series_months)
) |>
  mutate(
    date = ceiling_date(month, "month") - 1,
    shrout = runif(n(), 1, 50) * 1000,
    prc = runif(n(), 1, 1000),
    mktcap = shrout * prc / 1000,
    ret = rnorm(n(), mean = 0.008, sd = 0.10),
    ret_excess = pmax(ret - runif(n(), 0, 0.004), -1)
  ) |>
  arrange(permno, date) |>
  group_by(permno) |>
  mutate(mktcap_lag = lag(mktcap)) |>
  ungroup() |>
  select(
    permno, permco, gvkey, date, exchange, industry, siccd,
    shrout, prc, ret, ret_excess, mktcap, mktcap_lag
  )

# compustat_annual -------------------------------------------------------------
# The manuscript selects down to gvkey, date, at, ib. `date` is the fiscal
# year-end (Dec 31). Total assets follow a per-firm geometric random walk so
# year-over-year asset growth has a realistic spread; income before
# extraordinary items is roughly proportional to assets and turns negative for a
# minority of firm-years, exercising the earnings filter.
compustat_annual <- expand_grid(
  stock_identifiers |> select(gvkey),
  tibble(year = time_series_years)
) |>
  arrange(gvkey, year) |>
  group_by(gvkey) |>
  mutate(
    at = 100 * exp(cumsum(rnorm(n(), mean = 0.05, sd = 0.30)))
  ) |>
  ungroup() |>
  mutate(
    date = ymd(paste0(year, "-12-31")),
    ib = at * rnorm(n(), mean = 0.05, sd = 0.10)
  ) |>
  select(gvkey, date, at, ib)

# Write outputs ----------------------------------------------------------------
dir.create("data", showWarnings = FALSE)
write_parquet(crsp_monthly, "data/crsp_monthly.parquet")
write_parquet(compustat_annual, "data/compustat_annual.parquet")

message(
  sprintf(
    "Wrote dummy data: %s crsp_monthly rows (%d stocks), %s compustat_annual rows.",
    format(nrow(crsp_monthly), big.mark = ","),
    number_of_stocks,
    format(nrow(compustat_annual), big.mark = ",")
  )
)
