# Packages ----------------------------------------------------------------
library(dplyr)
library(lubridate)
library(tidyr)
library(arrow)

source("00_global_options.R")


# Source data -------------------------------------------------------------
# Load annual sorting variables
sorting_variables_yearly <- read_feather(paste0(data_raw_folder, "sorting_variables_yearly.feather"))

# Load quarterly sorting variables
sorting_variables_quarterly <- read_feather(paste0(data_raw_folder, "sorting_variables_quarterly.feather"))

# Load monthly sorting variables
sorting_variables_monthly <- read_feather(paste0(data_raw_folder, "sorting_variables_monthly.feather"))

# Load CRSP monthly
crsp_monthly <- read_feather(paste0(data_raw_folder, "crsp_monthly.feather")) |> 
  select(gvkey, permno, date, ret_excess, exchange, industry, mktcap_lag)


# Extract filter variables ------------------------------------------------
# Monthly
filter_monthly <- sorting_variables_monthly |> 
  select(permno, date, starts_with("filter_"))

sorting_variables_monthly <- sorting_variables_monthly |> 
  select(permno, date, starts_with("sv_"))

# Yearly
filter_yearly <- sorting_variables_yearly |> 
  select(gvkey, date, starts_with("filter_"))

sorting_variables_yearly <- sorting_variables_yearly |> 
  select(gvkey, date, starts_with("sv_"))

# Implement stock-age filter and sample restriction
crsp_monthly <- crsp_monthly |> 
  add_lagged_values(filter_monthly, "permno", min_lag = months(3), max_lag = months(12)) |>
  add_lagged_values(filter_yearly, "gvkey", min_lag = months(3), max_lag = months(12)) |> 
  filter(filter_stock_age >= 2) |> 
  filter(date>=date_start_returns, date<=date_end_returns) |>
  select(-filter_stock_age)


# Lag 3m ------------------------------------------------------------------
# Exactly lag by three months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag3m <- crsp_monthly |> 
  add_lagged_values(sorting_variables_monthly, "permno", min_lag = months(3), max_lag = months(12)) |>
  add_lagged_values(sorting_variables_quarterly, "gvkey", min_lag = months(3), max_lag = months(12)) |> 
  add_lagged_values(sorting_variables_yearly, "gvkey", min_lag = months(3), max_lag = months(12))

# Export 
sv_lag3m |> write_feather(paste0(data_raw_folder, "sv_lag3m.feather"))


# Lag 6m ------------------------------------------------------------------
# Exactly lag by six months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag6m <- crsp_monthly |> 
  add_lagged_values(sorting_variables_monthly, "permno", min_lag = months(6), max_lag = months(12)) |>
  add_lagged_values(sorting_variables_quarterly, "gvkey", min_lag = months(6), max_lag = months(12)) |> 
  add_lagged_values(sorting_variables_yearly, "gvkey", min_lag = months(6), max_lag = months(12))

# Export 
sv_lag6m |> write_feather(paste0(data_raw_folder, "sv_lag6m.feather"))


# Lag FF ------------------------------------------------------------------
# Lag variables from year t to July t+1
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lagFF <- crsp_monthly |> 
  add_lagged_values(sorting_variables_monthly, "permno", min_lag = months(18), max_lag = months(12), ff_adjustment = TRUE) |>
  add_lagged_values(sorting_variables_quarterly, "gvkey", min_lag = months(18), max_lag = months(12), ff_adjustment = TRUE) |> 
  add_lagged_values(sorting_variables_yearly, "gvkey", min_lag = months(18), max_lag = months(12), ff_adjustment = TRUE)

# Export 
sv_lagFF |> write_feather(paste0(data_raw_folder, "sv_lagFF.feather"))