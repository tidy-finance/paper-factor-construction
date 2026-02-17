library(dplyr)
library(tidyr)
library(tidyfinance)
library(arrow)

source("code/00_global_options.R")

download_data(
  domain = "factors_ff",
  dataset = "Fama/French 5 Factors (2x3)"
) |>
  write_parquet(file.path(data_folder, "factors_ff_3_monthly.parquet"))

download_data(
  domain = "factors_ff",
  dataset = "Fama/French 5 Factors (2x3) [Daily]"
) |>
  write_parquet(file.path(data_folder, "factors_ff_3_daily.parquet"))

# CRSP Compustat linking table --------------------------------------------
ccm_link <- download_data(
  domain = "wrds",
  dataset = "ccm_links",
  linktype = c("LU", "LC"),
  linkprim = c("P", "C")
)

crsp_monthly <- download_data(
  domain = "wrds",
  dataset = "crsp_monthly",
  version = "v1",
  start_date = date_start,
  end_date = date_end,
  additional_columns = c("retx", "cfacpr")
)

crsp_monthly <- crsp_monthly |>
  drop_na(mktcap_lag) |>
  mutate(
    prc_adj = abs(na_if(altprc, 0)) / cfacpr,
    prc_adj = if_else(is.infinite(prc_adj), NA_real_, prc_adj)
  ) |>
  select(-cfacpr)

# Add link to crsp_monthly
ccm_link <- crsp_monthly |>
  inner_join(
    ccm_link,
    join_by(permno),
    relationship = "many-to-many",
    multiple = "all"
  ) |>
  filter(!is.na(gvkey) & (date >= linkdt & date <= linkenddt)) |>
  select(permno, gvkey, date)

crsp_monthly <- crsp_monthly |>
  left_join(ccm_link, join_by(permno, date)) |>
  mutate(exchange = as.factor(exchange), industry = as.factor(industry))

write_parquet(
  crsp_monthly,
  file.path(data_folder, "crsp_monthly.parquet")
)

crsp_daily <- download_data(
  domain = "wrds",
  dataset = "crsp_daily",
  version = "v1",
  start_date = date_start,
  end_date = date_end,
  batch_size = 500,
  additional_columns = c("shrout", "prc", "vol", "cfacpr", "ret", "exchcd")
)

# Gao and Ritter (2010) volume adjustment to ensure NASDAQ trading volume
gr_date_1 <- as.Date("2001-02-01")
gr_date_2 <- as.Date("2002-01-01")
gr_date_3 <- as.Date("2004-01-01")

crsp_daily <- crsp_daily |>
  mutate(
    vol = na_if(vol, -99),
    prc = na_if(prc, 0),
    prc_adj = abs(prc) / cfacpr,
    prc_adj = if_else(is.infinite(prc_adj), NA_real_, prc_adj)
  ) |>
  mutate(
    vol_adj = case_when(
      exchcd == 3 & date < gr_date_1 ~ vol / 2.0,
      exchcd == 3 & date >= gr_date_1 & date < gr_date_2 ~ vol / 1.8,
      exchcd == 3 & date >= gr_date_2 & date < gr_date_3 ~ vol / 1.6,
      exchcd == 3 & date >= gr_date_3 ~ vol / 1.0,
      .default = vol
    )
  ) |>
  select(-exchcd, -vol)

write_parquet(
  crsp_daily,
  file.path(data_folder, "crsp_daily.parquet")
)

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
    "fincf",
    "fopt",
    "ib",
    "ivncf",
    "invt",
    "itcb",
    "ivao",
    "ivst",
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
  )
)

# Remove Canadian observations
compustat_annual <- compustat_annual |>
  filter(curcd == "USD") |>
  select(-curcd)

# Replace negative numbers with missing values
compustat_annual <- compustat_annual |>
  mutate(
    across(
      .cols = c("sale", "at", "capx", "invt"),
      .fns = ~ if_else(.x < 0, NA_real_, .x)
    )
  )

write_parquet(
  compustat_annual,
  file.path(data_folder, "compustat_annual.parquet")
)

compustat_quarterly <- download_data(
  domain = "wrds",
  dataset = "compustat_quarterly",
  start_date = date_start,
  end_date = date_end,
  additional_columns = c(
    "rdq",
    "fyearq",
    "fqtr",
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
  )
)

# Remove Canadian observations
compustat_quarterly <- compustat_quarterly |>
  filter(curcdq == "USD") |>
  select(-curcdq)

# Replace negative values of total assets and sales with zero
compustat_quarterly <- compustat_quarterly |>
  mutate(
    across(
      .cols = c("atq", "saleq"),
      .fns = ~ if_else(.x < 0, NA_real_, .x)
    )
  )

write_parquet(
  compustat_quarterly,
  file.path(data_folder, "compustat_quarterly.parquet")
)
