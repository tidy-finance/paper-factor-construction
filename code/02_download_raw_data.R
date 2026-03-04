library(dplyr)
library(tidyr)
library(tidyfinance)
library(arrow)

date_start <- as.Date("1960-01-01")
date_end <- as.Date("2024-12-31")

download_data(
  domain = "factors_ff",
  dataset = "Fama/French 5 Factors (2x3)",
  start_date = date_start,
  end_date = date_end
) |>
  write_parquet("data/factors_ff_3_monthly.parquet")

download_data(
  domain = "factors_ff",
  dataset = "Fama/French 5 Factors (2x3) [Daily]",
  start_date = date_start,
  end_date = date_end
) |>
  write_parquet("data/factors_ff_3_daily.parquet")

crsp_monthly <- download_data(
  domain = "wrds",
  dataset = "crsp_monthly",
  version = "v2",
  start_date = date_start,
  end_date = date_end,
  add_ccm_links = TRUE
) |>
  mutate(exchange = as.factor(exchange), industry = as.factor(industry))

write_parquet(crsp_monthly, "data/crsp_monthly.parquet")

crsp_daily <- download_data(
  domain = "wrds",
  dataset = "crsp_daily",
  version = "v2",
  start_date = date_start,
  end_date = date_end,
  batch_size = 500,
  additional_columns = c("shrout", "dlyprc"),
  adjust_volume = TRUE
) |>
  rename(prc = dlyprc, facprc = dlyfacprc)

write_parquet(crsp_daily, "data/crsp_daily.parquet")

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
  only_us = TRUE
) |>
  select(-curcd)

# Replace negative numbers with missing values
compustat_annual <- compustat_annual |>
  mutate(
    across(
      .cols = c("sale", "at", "capx", "invt"),
      .fns = ~ if_else(.x < 0, NA_real_, .x)
    )
  )

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
  only_us = TRUE
) |>
  select(-curcdq)

# Replace negative values of total assets and sales with zero
compustat_quarterly <- compustat_quarterly |>
  mutate(
    across(
      .cols = c("atq", "saleq"),
      .fns = ~ if_else(.x < 0, NA_real_, .x)
    )
  )

write_parquet(compustat_quarterly, "data/compustat_quarterly.parquet")
