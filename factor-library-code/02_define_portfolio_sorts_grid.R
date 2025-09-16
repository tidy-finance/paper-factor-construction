# Construct portfolio sorting grid

# Packages ----------------------------------------------------------------
library(dplyr)
library(tidyr)
library(forcats)
library(tibble)
library(arrow)

source("00_global_options.R")


# Load data ---------------------------------------------------------------
sv_directions <- read_feather(paste0(data_raw_folder, "sv_directions.feather"))


# Construct grid ----------------------------------------------------------
# Construct full grid
full_grid <- expand_grid(
  sorting_variable = unique(sv_directions$sorting_variable),
  exclude_size = c(0, 0.2),
  exclude_financials = c(TRUE, FALSE),
  exclude_utilities = c(TRUE, FALSE),
  exclude_negative_earnings = c(TRUE, FALSE),
  sorting_variable_lag = c("3m", "6m", "FF"),
  rebalancing = c("monthly", "annual"),
  breakpoints_main = c(5, 10),
  sorting_method = c("univariate", "bivariate-dependent", "bivariate-independent"),
  breakpoints_secondary = c(2, 5),
  breakpoints_exchanges = c("NYSE", "AMEX|NASDAQ|NYSE"),
  weighting_scheme = c("EW", "VW") # Weighting scheme at last position ensures that running ID even for EW and uneven for VW
)

# Revise breakpoints_secondary
grid <- full_grid |> 
  filter(!(sorting_method == "univariate" & breakpoints_secondary > min(full_grid$breakpoints_secondary))) |> 
  mutate(breakpoints_secondary = if_else(sorting_method == "univariate", NA_real_, breakpoints_secondary))

# Revise sv_me's double sorts
grid <- grid |> 
  filter(!(sorting_variable == "sv_me" & sorting_method %in% c("bivariate-dependent", "bivariate-independent")))

# Revise sv_em and exclude_negative_earnings combination
grid <- grid |> filter(!(sorting_variable == "sv_em" & exclude_negative_earnings == FALSE))


# Sort grid ---------------------------------------------------------------
grid <- grid |> 
  arrange(sorting_variable_lag, sorting_variable)

# Add ID
grid <- grid |> 
  rowid_to_column(var = "ID")

# Add sequencer ID 

grid <- grid |> left_join(
  grid |> 
    mutate(across(-c(ID, sorting_variable), \(x) fct_na_value_to_level(as.factor(x))),
           across(where(is.factor), \(x) as.integer(fct_inorder(x)) - 1)) |>
    unite("ID_sequence", -c(ID, sorting_variable), sep = "") |> 
    select(ID, ID_sequence),
  join_by(ID)
) |> 
  select(ID, ID_sequence, everything())

# Save --------------------------------------------------------------------
grid |> write_feather(paste0(data_raw_folder, "portfolio_sort_grid.feather"))

