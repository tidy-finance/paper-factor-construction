# Compute annual sorting variables


# Packages ----------------------------------------------------------------
library(dplyr)
library(tidyr)
library(purrr)
library(lubridate)
library(multidplyr)
library(arrow)
library(slider)

source("00_global_options.R")

cluster <- new_cluster(parallel::detectCores()-1)
cluster_library(cluster, c("lubridate", "slider", "dplyr"))

# Data --------------------------------------------------------------------
# Load annual compustat
compustat_quarterly <- open_dataset(paste0(data_raw_folder, "compustat_quarterly.feather"),
                                 format = "feather")

# Load CRSP
crsp_monthly <- open_dataset(paste0(data_raw_folder, "crsp_monthly.feather"),
                             format = "feather")

# Add relevant CRSP items
compustat_quarterly <- compustat_quarterly |>
  left_join(crsp_monthly |>
              select(gvkey, date, mktcap, siccd),
            join_by(gvkey, date), 
            relationship = "one-to-one") |>
  collect()

# Intermediate variables --------------------------------------------------
# Create variables
compustat_quarterly <- compustat_quarterly |>
  mutate(int_rps = saleq/(cshprq * ajexq),
         int_sue = epspxq/ajexq,
         int_beq = coalesce(seqq, ceqq + pstkq, atq - ltq) +
           coalesce(txditcq, txdbq, 0) -
           coalesce(pstkrq, pstkq, 0)
         ) |>
  rename(int_me = mktcap)

# Lag certain variables
## One quarter lag
compustat_quarterly_lag1 <- compustat_quarterly |>
  select(gvkey, date, atq, int_beq) |>
  mutate(date = date %m+% months(3)) |>
  rename_with(.cols = -c("gvkey", "date"),
              .fn = ~ paste0(.x, "_lag1"))

## Four quarter lag
compustat_quarterly_lag4 <- compustat_quarterly |>
  select(gvkey, date, int_rps, int_sue) |>
  mutate(date = date %m+% months(12)) |>
  rename_with(.cols = -c("gvkey", "date"),
              .fn = ~ paste0(.x, "_lag4"))

# Merge back
compustat_quarterly <- compustat_quarterly |>
  left_join(compustat_quarterly_lag1, join_by(gvkey, date), relationship = "one-to-one") |>
  left_join(compustat_quarterly_lag4, join_by(gvkey, date), relationship = "one-to-one")


# Variables with rolling windows ------------------------------------------

# Revenue surprise --------------------------------------------------------

cluster_copy(cluster, "compute_rolling_sd")

# Estimate sorting variable
compustat_quarterly_rs <- compustat_quarterly |>
  mutate(int_drps = int_rps - int_rps_lag4,
         int_drps = if_else(is.nan(int_drps) | is.infinite(int_drps), NA_real_, int_drps))|>
  select(gvkey, date, int_drps) |>
  drop_na() |>
  arrange(gvkey, date) |>
  group_by(gvkey) |>
  partition(cluster) |>
  mutate(sd_drps = compute_rolling_sd(pick(everything()), 
                                      column = int_drps, 
                                      quarters = 8, 
                                      min_obs = 6),
         sv_rs = int_drps / sd_drps,
         sv_rs = if_else(date >= as.Date("1972-01-01"), sv_rs, NA_real_)) |>
  collect() |>
  ungroup() |>
  select(gvkey, date, sv_rs) |>
  drop_na()

# Remerge
compustat_quarterly <- compustat_quarterly |>
  left_join(compustat_quarterly_rs, join_by(gvkey, date), relationship = "one-to-one")

# Standardized unexpected earnings --------------------------------------------

# Estimate sorting variable
compustat_quarterly_sue <- compustat_quarterly |>
  mutate(int_sue = int_sue - int_sue_lag4,
         int_sue = if_else(is.nan(int_sue) | is.infinite(int_sue), NA_real_, int_sue))|>
  select(gvkey, date, int_sue) |>
  drop_na() |>
  arrange(gvkey, date) |>
  group_by(gvkey) |>
  partition(cluster) |> 
  mutate(sd_sue = compute_rolling_sd(pick(everything()), 
                                     column = int_sue, 
                                     quarters = 8, 
                                     min_obs = 6),
         sv_sue = int_sue / sd_sue,
         sv_sue = if_else(date >= as.Date("1972-01-01"), sv_sue, NA_real_)) |>
  collect() |> 
  ungroup() |>
  select(gvkey, date, sv_sue) |>
  drop_na()

# Remerge
compustat_quarterly <- compustat_quarterly |>
  left_join(compustat_quarterly_sue, join_by(gvkey, date), relationship = "one-to-one")

# Main variables ----------------------------------------------------------
sorting_variables_quarterly <- compustat_quarterly |>
  mutate(sv_roa = ibq/atq_lag1,
         sv_roe = ibq/int_beq_lag1)

# Filters -----------------------------------------------------------------
# Remove Inf and NaN
sorting_variables_quarterly <- sorting_variables_quarterly |>
  mutate(across(starts_with("sv_"), ~ na_if(., Inf)),
         across(starts_with("sv_"), ~ na_if(., -Inf)),
         across(starts_with("sv_"), ~ if_else(is.nan(.x), NA_real_, .x)))


# Final -------------------------------------------------------------------
# Select
sorting_variables_quarterly <- sorting_variables_quarterly |>
  select(gvkey, date, starts_with("sv_"))

# Save
sorting_variables_quarterly |>
  write_feather(paste0(data_raw_folder, "sorting_variables_quarterly.feather"))
