library(tidyverse)
library(tidyfinance)
library(here)
library(arrow)

source("factor-library-code/00_global_options.R")

download_data(
  "factors_ff_3_monthly"
) |>
  write_parquet(here(data_folder, "factors_ff_3_monthly.parquet"))

download_data(
  "factors_ff_3_daily"
) |>
  write_parquet(here(data_folder, "factors_ff_3_daily.parquet"))

# CRSP Compustat linking table --------------------------------------------
ccm_link <- download_data_wrds_ccm_links(
  linktype = c("LU", "LC"),
  linkprim = c("P", "C")
)

crsp_monthly <- download_data_wrds_crsp(
  type = "crsp_monthly",
  version = "v1",
  start_date = date_start_data,
  end_date = date_end_data,
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
  left_join(ccm_link, join_by(permno, date))

crsp_monthly |>
  write_parquet(here(data_folder, "crsp_monthly.parquet"))

crsp_daily <- download_data_wrds_crsp(
  type = "crsp_daily",
  version = "v1",
  start_date = date_start_data,
  end_date = date_end_data,
  batch_size = 500,
  additional_columns = c("shrout", "prc", "vol", "cfacpr", "ret", "exchcd")
)

# Gao and Ritter volume adjustment
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

crsp_daily |>
  write_parquet(here(data_folder, "crsp_daily.parquet"))

compustat_annual <- download_data_wrds_compustat(
  type = "wrds_compustat_annual",
  start_date = date_start_data,
  end_date = date_end_data,
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

# Remove negative numbers
compustat_annual <- compustat_annual |>
  mutate(across(
    .cols = c("sale", "at", "capx", "invt"),
    .fns = ~ if_else(.x < 0, NA_real_, .x)
  ))

# Save data
compustat_annual |>
  write_parqet(here(data_folder, "compustat_annual.parquet"))

compustat_quarterly <- download_data_wrds_compustat(
  type = "wrds_compustat_quarterly",
  start_date = date_start_data,
  end_date = date_end_data,
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

# Replace negative values of total assets with zero and sales
compustat_quarterly <- compustat_quarterly |>
  mutate(
    atq = if_else(atq < 0, NA_real_, atq),
    saleq = if_else(saleq < 0, NA_real_, saleq)
  )

# Save data
compustat_quarterly |>
  write_parquet(here(data_folder, "compustat_quarterly.parquet"))
