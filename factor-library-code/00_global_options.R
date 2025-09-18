# Set global options

# Dates -------------------------------------------------------------------
date_start_data <- as.Date("1960-01-01")
date_end_data <- as.Date("2024-12-31")

# Naming ------------------------------------------------------------------

mapping_nodes <- tibble(
  node = c(
    "exclude_size",
    "exclude_financials",
    "exclude_utilities",
    "exclude_negative_earnings",
    "sorting_variable_lag",
    "rebalancing",
    "breakpoints_main",
    "sorting_method",
    "breakpoints_secondary",
    "breakpoints_exchanges",
    "weighting_scheme"
  ),
  node_label = c(
    "Exclusion (size)",
    "Exclusion (financials)",
    "Exclusion (utilities)",
    "Exclusion (neg. earnings)",
    "Sorting variable (lag)",
    "Rebalancing frequency",
    "Breakpoints (primary)",
    "Sorting method",
    "Breakpoints (secondary)",
    "Breakpoints (Listing exchange)",
    "Weighting scheme"
  ),
  node_order = 1:11
)

relabel_paths <- function(data) {
  data |>
    mutate(
      exclude_size = if_else(exclude_size == 0, "No", "Yes (20%)"),
      exclude_financials = if_else(exclude_financials, "Yes", "No"),
      exclude_utilities = if_else(exclude_utilities, "Yes", "No"),
      exclude_negative_earnings = if_else(
        exclude_negative_earnings,
        "Yes",
        "No"
      ),
      sorting_variable_lag = sorting_variable_lag,
      rebalancing = if_else(rebalancing == "monthly", "Monthly", "Annual"),
      sorting_method = case_when(
        sorting_method == "univariate" ~ "Univariate",
        sorting_method == "bivariate-independent" ~ "Bivariate (indep.)",
        sorting_method == "bivariate-dependent" ~ "Bivariate (dep.)",
        .default = NA
      ),
      breakpoints_secondary = breakpoints_secondary,
      breakpoints_exchanges = if_else(
        breakpoints_exchanges == "NYSE",
        "NYSE",
        "AMEX, NASDAQ & NYSE"
      ),
      weighting_scheme = weighting_scheme
    )
}

# Helper functions --------------------------------------------------------
# Rolling SD -----
compute_rolling_sd <- function(data, column, quarters, min_obs) {
  rolling_sd <- slider::slide_period_vec(
    .x = data |> pull({{ column }}),
    .i = data$date,
    .period = "quarter",
    .f = ~ if_else(sum(!is.na(.x)) < min_obs, NA_real_, sd(.x, na.rm = TRUE)),
    .before = quarters - 1,
    .complete = FALSE
  )

  return(rolling_sd)
}


# Lagged values -----
add_lagged_values <- function(
  original_data,
  new_data,
  id_keys,
  id_date = "date",
  min_lag,
  max_lag,
  ff_adjustment = FALSE
) {
  new_column_names <- new_data |>
    select(-all_of(c(id_keys, id_date))) |>
    names()

  if (ff_adjustment) {
    new_data <- new_data |>
      mutate(
        ..year = year(.data[[id_date]]),
        ..lower_bound = floor_date(.data[[id_date]], unit = "year") %m+%
          min_lag,
        ..upper_bound = ..lower_bound %m+% max_lag
      )
  } else {
    new_data <- new_data |>
      mutate(
        ..lower_bound = .data[[id_date]] %m+% min_lag,
        ..upper_bound = ..lower_bound %m+% max_lag
      )
  }

  for (column_name in new_column_names) {
    if (ff_adjustment) {
      tmp_data <- new_data |>
        select(
          ..lower_bound,
          ..upper_bound,
          ..year,
          all_of(c(id_keys, id_date, column_name))
        ) |>
        tidyr::drop_na(!!!column_name) |>
        group_by(.data[[id_keys]], ..year) |>
        slice_max(.data[[id_date]], n = 1) |>
        ungroup() |>
        select(-all_of(id_date))
    } else {
      tmp_data <- new_data |>
        select(..lower_bound, ..upper_bound, all_of(c(id_keys, column_name))) |>
        tidyr::drop_na(!!!column_name)
    }

    column_values <- original_data |>
      select(..date := all_of(id_date), everything()) |>
      left_join(
        tmp_data,
        join_by(
          !!!id_keys,
          closest(..date >= ..lower_bound),
          ..date < ..upper_bound
        )
      ) |>
      select(all_of(column_name)) |>
      pull()

    original_data <- original_data |>
      mutate("{column_name}" := column_values)
  }

  return(original_data)
}
