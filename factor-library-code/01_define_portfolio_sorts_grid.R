library(tidyr)
library(dplyr)
library(tibble)
library(forcats)
library(arrow)

source("factor-library-code/00_global_options.R")

sorting_variable_directions <- tibble::tribble(
  ~sorting_variable,
  ~direction,
  "mom",
  "top_minus_bottom",
  "rmom",
  "top_minus_bottom",
  "rs",
  "top_minus_bottom",
  "sue",
  "top_minus_bottom",
  "52w",
  "top_minus_bottom",
  "me",
  "bottom_minus_top",
  "cbop",
  "top_minus_bottom",
  "gpa",
  "top_minus_bottom",
  "o",
  "bottom_minus_top",
  "ope",
  "top_minus_bottom",
  "roa",
  "top_minus_bottom",
  "roe",
  "top_minus_bottom",
  "tbi",
  "top_minus_bottom",
  "bm",
  "top_minus_bottom",
  "cfm",
  "top_minus_bottom",
  "dm",
  "top_minus_bottom",
  "ebm",
  "top_minus_bottom",
  "em",
  "top_minus_bottom",
  "ndm",
  "bottom_minus_top",
  "npy",
  "top_minus_bottom",
  "ocm",
  "top_minus_bottom",
  "rev",
  "bottom_minus_top",
  "sm",
  "top_minus_bottom",
  "aci",
  "bottom_minus_top",
  "ag",
  "bottom_minus_top",
  "dinv",
  "bottom_minus_top",
  "dnoa",
  "bottom_minus_top",
  "dpia",
  "bottom_minus_top",
  "dwc",
  "bottom_minus_top",
  "ig",
  "bottom_minus_top",
  "noa",
  "bottom_minus_top",
  "oa",
  "bottom_minus_top",
  "cdi",
  "bottom_minus_top",
  "csi",
  "bottom_minus_top",
  "dbe",
  "bottom_minus_top",
  "dcol",
  "bottom_minus_top",
  "dfnl",
  "bottom_minus_top",
  "ndf",
  "bottom_minus_top",
  "nef",
  "bottom_minus_top",
  "nxf",
  "bottom_minus_top",
  "hr",
  "bottom_minus_top",
  "ol",
  "top_minus_bottom",
  "rer",
  "top_minus_bottom",
  "ami",
  "top_minus_bottom",
  "beta",
  "top_minus_bottom",
  "dtv",
  "bottom_minus_top",
  "iskew",
  "bottom_minus_top",
  "ivol",
  "bottom_minus_top",
  "mdr",
  "bottom_minus_top",
  "tur",
  "bottom_minus_top"
)

sorting_variable_directions |>
  write_parquet(here::here(data_folder, "sorting_variables_directions.parquet"))

full_grid <- expand_grid(
  sorting_variable = unique(sorting_variable_directions$sorting_variable),
  exclude_size = c(0, 0.2),
  exclude_financials = c(TRUE, FALSE),
  exclude_utilities = c(TRUE, FALSE),
  exclude_negative_earnings = c(TRUE, FALSE),
  sorting_variable_lag = c("3m", "6m", "FF"),
  rebalancing = c("monthly", "annual"),
  breakpoints_main = c(5, 10),
  sorting_method = c(
    "univariate",
    "bivariate-dependent",
    "bivariate-independent"
  ),
  breakpoints_secondary = c(2, 5),
  breakpoints_exchanges = c("NYSE", "AMEX|NASDAQ|NYSE"),
  weighting_scheme = c("EW", "VW") # Weighting scheme at last position ensures that running ID even for EW and uneven for VW
)

# Revise breakpoints_secondary
grid <- full_grid |>
  filter(
    !(sorting_method == "univariate" &
      breakpoints_secondary > min(full_grid$breakpoints_secondary))
  ) |>
  mutate(
    breakpoints_secondary = if_else(
      sorting_method == "univariate",
      NA_real_,
      breakpoints_secondary
    )
  )

# Revise sv_me's double sorts
grid <- grid |>
  filter(
    !(sorting_variable == "sv_me" &
      sorting_method %in% c("bivariate-dependent", "bivariate-independent"))
  )

# Revise sv_em and exclude_negative_earnings combination
grid <- grid |>
  filter(!(sorting_variable == "sv_em" & exclude_negative_earnings == FALSE))


# Sort grid ---------------------------------------------------------------
grid <- grid |>
  arrange(sorting_variable_lag, sorting_variable) |>
  rowid_to_column(var = "ID")

# Add sequencer ID

grid <- grid |>
  left_join(
    grid |>
      mutate(
        across(-c(ID, sorting_variable), \(x) {
          fct_na_value_to_level(as.factor(x))
        }),
        across(where(is.factor), \(x) as.integer(fct_inorder(x)) - 1)
      ) |>
      unite("ID_sequence", -c(ID, sorting_variable), sep = "") |>
      select(ID, ID_sequence),
    join_by(ID)
  ) |>
  select(ID, ID_sequence, everything())

grid |>
  write_parquet(here::here(
    data_folder,
    "portfolio_sort_grid.parquet"
  ))
