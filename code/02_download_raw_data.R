library("dplyr")
library("tidyr")
library("tidyfinance")
library("arrow")

date_start <- as.Date("1960-01-01")
date_end <- as.Date("2024-12-31")

download_data(
  domain = "factors_ff",
  dataset = "Fama/French 5 Factors (2x3)",
  start_date = date_start,
  end_date = date_end
) |>
  write_parquet("data/factors_ff_5_monthly.parquet")

download_data(
  domain = "factors_ff",
  dataset = "Fama/French 5 Factors (2x3) [Daily]",
  start_date = date_start,
  end_date = date_end
) |>
  write_parquet("data/factors_ff_5_daily.parquet")

crsp_monthly <- download_data(
  domain = "wrds",
  dataset = "crsp_monthly",
  version = "v2",
  start_date = date_start,
  end_date = date_end,
  add_ccm_links = TRUE
)

crsp_monthly |>
  write_parquet("data/crsp_monthly.parquet")

download_data(
  domain = "wrds",
  dataset = "crsp_daily",
  version = "v2",
  start_date = date_start,
  end_date = date_end,
  additional_columns = c(
    "shrout",
    "dlyprc",
    "dlyvol",
    "primaryexch",
    "dlyfacprc"
  ),
  adjust_volume = TRUE
) |>
  write_parquet("data/crsp_daily.parquet")

compustat_annual <- download_data(
  domain = "wrds",
  dataset = "compustat_annual",
  start_date = date_start,
  end_date = date_end,
  additional_columns = c(
    "act",
    "ap",
    "at",
    "capx",
    "che",
    "cogs",
    "dlc",
    "dlcch",
    "dltr",
    "dltt",
    "dltis",
    "dp",
    "drc",
    "drlt",
    "dv",
    "dvc",
    "dvpa",
    "emp",
    "fatb",
    "fatl",
    "fopt",
    "ib",
    "invt",
    "itcb",
    "lct",
    "lt",
    "mib",
    "ni",
    "oancf",
    "pi",
    "prstkc",
    "pstkl",
    "pstkrv",
    "ppegt",
    "ppenb",
    "ppenls",
    "ppent",
    "pstk",
    "revt",
    "sale",
    "curcd",
    "seq",
    "sstk",
    "tstkp",
    "txdb",
    "txditc",
    "txp",
    "wcap",
    "xacc",
    "xint",
    "xsga",
    "xpp",
    "xrd"
  ),
  only_usd = TRUE
)

# Replace negative values with missing values
compustat_annual <- compustat_annual |>
  mutate(
    across(
      .cols = c("sale", "at", "capx", "invt"),
      .fns = ~ if_else(.x < 0, NA_real_, .x)
    )
  ) |>
  # Filter to firms that are present in the CRSP monthly dataset
  filter(gvkey %in% unique(crsp_monthly$gvkey)) |>
  select(-at_lag)

write_parquet(compustat_annual, "data/compustat_annual.parquet")

compustat_quarterly <- download_data(
  domain = "wrds",
  dataset = "compustat_quarterly",
  start_date = date_start,
  end_date = date_end,
  additional_columns = c(
    "curcdq",
    "ajexq",
    "atq",
    "ceqq",
    "cshprq",
    "epspxq",
    "ibq",
    "ltq",
    "pstkrq",
    "pstkq",
    "saleq",
    "seqq",
    "txdbq",
    "txditcq"
  ),
  only_usd = TRUE
) |>
  select(-curcdq)

# Replace negative values of total assets and sales with missing values
compustat_quarterly <- compustat_quarterly |>
  mutate(
    across(
      .cols = c("atq", "saleq"),
      .fns = ~ if_else(.x < 0, NA_real_, .x)
    )
  ) |>
  # Filter to firms that are present in the CRSP monthly dataset
  filter(gvkey %in% unique(crsp_monthly$gvkey))

write_parquet(compustat_quarterly, "data/compustat_quarterly.parquet")
