library(dplyr)
library(lubridate)
library(arrow)
library(here)

source("factor-library-code/00_global_options.R")

sorting_variables_yearly <- read_parquet(
  here(data_folder, "sorting_variables_yearly.parquet")
)

sorting_variables_quarterly <- read_parquet(
  here(data_folder, "sorting_variables_quarterly.parquet")
)

sorting_variables_monthly <- read_parquet(
  here(data_folder, "sorting_variables_monthly.parquet")
)

crsp_monthly <- open_dataset(
  here(data_folder, "crsp_monthly.parquet")
) |>
  select(gvkey, permno, date, ret_excess, exchange, industry, mktcap_lag) |>
  collect()

filter_monthly <- sorting_variables_monthly |>
  select(permno, date, starts_with("filter_"))

sorting_variables_monthly <- sorting_variables_monthly |>
  select(permno, date, starts_with("sv_"))

filter_yearly <- sorting_variables_yearly |>
  select(gvkey, date, starts_with("filter_"))

sorting_variables_yearly <- sorting_variables_yearly |>
  select(gvkey, date, starts_with("sv_"))

# TODO: replace with function from r-tidyfinance
add_lagged_values <- function(
  original_data,
  new_data,
  id_keys,
  id_date = "date",
  min_lag,
  max_lag,
  ff_adjustment = FALSE
) {
  stopifnot(is.character(id_keys))
  stopifnot(id_date %in% names(original_data))
  stopifnot(id_date %in% names(new_data))

  new_column_names <- new_data |>
    dplyr::select(-dplyr::all_of(c(id_keys, id_date))) |>
    names()

  new_data <- new_data |>
    dplyr::mutate(
      .lower = .data[[id_date]] %m+% min_lag,
      .upper = .lower %m+% max_lag
    )

  if (ff_adjustment) {
    new_data <- new_data |>
      dplyr::mutate(.year = lubridate::year(.data[[id_date]]))
  }

  for (col_name in new_column_names) {
    tmp_data <- new_data |>
      dplyr::select(
        dplyr::all_of(c(id_keys, id_date, col_name, ".lower", ".upper")),
        dplyr::any_of(".year")
      )

    if (ff_adjustment) {
      tmp_data <- tmp_data |>
        dplyr::group_by(dplyr::across(all_of(c(id_keys, ".year")))) |>
        dplyr::slice_max(order_by = .data[[id_date]], n = 1) |>
        dplyr::ungroup() |>
        dplyr::select(-dplyr::all_of(id_date))
    }

    col_values <- original_data |>
      dplyr::rename(.date = dplyr::all_of(id_date)) |>
      dplyr::left_join(
        tmp_data,
        dplyr::join_by(
          !!!rlang::syms(id_keys),
          closest(.date >= .lower),
          .date < .upper
        )
      ) |>
      dplyr::pull(dplyr::all_of(col_name))

    original_data <- original_data |>
      dplyr::mutate("{col_name}" := col_values)
  }

  original_data
}

crsp_monthly <- crsp_monthly |>
  add_lagged_values(
    filter_monthly,
    "permno",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  add_lagged_values(
    filter_yearly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  filter(filter_stock_age >= min_stock_age) |>
  filter(date >= date_start, date <= date_end) |>
  select(-filter_stock_age)

# Lag 3m ------------------------------------------------------------------
# Exactly lag by three months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag3m <- crsp_monthly |>
  add_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  add_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  add_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  )

write_parquet(
  sv_lag3m,
  here(data_folder, "sorting_variables_lag_3m.parquet")
)

# Lag 6m ------------------------------------------------------------------
# Exactly lag by six months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag6m <- crsp_monthly |>
  add_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(6),
    max_lag = months(12)
  ) |>
  add_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(12)
  ) |>
  add_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(12)
  )

write_parquet(
  sv_lag6m,
  here(data_folder, "sorting_variables_lag_6m.parquet")
)

# Lag FF ------------------------------------------------------------------
# Lag variables from year t to July t+1
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

# TODO: why was min_lag > max_lag?
# TODO: why does this take forever?
sv_lag_ff <- crsp_monthly |>
  add_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  ) |>
  add_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  ) |>
  add_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  )

write_parquet(
  sv_lag_ff,
  here(data_folder, "sorting_variables_lag_ff.parquet")
)
