library(dplyr)
library(lubridate)
library(arrow)
library(tidyr)
library(tidyfinance)
library(here)
library(furrr)
library(future)
library(future.batchtools)

source("factor-library-code/00_global_options.R")

# SLURM task setup -------------------------------------------------------

slurm_task_id <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID"))
full_grid <- read_parquet(here(data_folder, "portfolio_sort_grid.parquet"))

if (!is.na(slurm_task_id)) {
  # Running on SLURM: take this worker's chunk
  task_id <- as.numeric(slurm_task_id)
  tasks_per_worker <- 100
  task_ids <- tibble(
    task_id = (task_id - 1) * tasks_per_worker + seq(tasks_per_worker)
  )
  grid <- full_grid |>
    mutate(task_id = row_number()) |>
    inner_join(task_ids, join_by(task_id))
} else {
  # Local execution: process everything
  set.seed(1234)
  grid <- full_grid |>
    mutate(task_id = row_number()) |>
    # TODO: clarify why the sv_ prefix is everywhere but this script
    mutate(sorting_variable = paste0("sv_", sorting_variable)) |>
    slice_sample(n = 10)
}

required_sorting_variables <- grid |>
  distinct(sorting_variable) |>
  pull()

required_datasets <- grid |>
  distinct(sorting_variable_lag) |>
  pull()

sv_directions <- read_parquet(
  here(data_folder, "sorting_variable_information.parquet")
) |>
  select(sorting_variable, direction) |>
  # TODO: see above (figure out why sv_ prefix is missing here)
  mutate(sorting_variable = paste0("sv_", sorting_variable))

grid <- grid |>
  inner_join(sv_directions, join_by(sorting_variable))

# Helper to read sorting data --------------------------------------------

read_sorting_data <- function(lag_label) {
  path <- here(
    data_folder,
    paste0("sorting_variables_lag_", lag_label, ".parquet")
  )
  open_dataset(path) |>
    select(
      permno,
      date,
      ret_excess,
      exchange,
      industry,
      filter_earnings,
      mktcap_lag,
      all_of(required_sorting_variables)
    ) |>
    collect()
}

sorting_data_cache <- setNames(
  lapply(required_datasets, read_sorting_data),
  required_datasets
)

# Helper to process individual task --------------------------------------

process_task <- function(row, sorting_data_cache) {
  sorting_data <- sorting_data_cache[[row$sorting_variable_lag]]

  if (row$exclude_size != 0) {
    sorting_data <- sorting_data |>
      group_by(date) |>
      filter(
        mktcap_lag >= quantile(mktcap_lag[exchange == "NYSE"], row$exclude_size)
      ) |>
      ungroup()
  }

  if (row$exclude_financials) {
    sorting_data <- sorting_data |>
      filter(industry != "Finance")
  }

  if (row$exclude_utilities) {
    sorting_data <- sorting_data |>
      filter(industry != "Utilities")
  }

  if (row$exclude_negative_earnings) {
    sorting_data <- sorting_data |>
      filter(filter_earnings > 0)
  }

  sorting_data <- sorting_data |>
    select(
      permno,
      date,
      ret_excess,
      all_of(row$sorting_variable),
      exchange,
      mktcap_lag
    ) |>
    drop_na(all_of(row$sorting_variable))

  rebalancing_month <- if (row$rebalancing == "monthly") NULL else 7

  options_main <- breakpoint_options(
    n_portfolios = row$breakpoints_main,
    breakpoint_exchanges = strsplit(row$breakpoints_exchanges, split = "\\|")[[
      1
    ]]
  )

  sorting_variables <- row$sorting_variable
  options_secondary <- NULL

  if (row$sorting_method != "univariate") {
    sorting_variables <- c(row$sorting_variable, "mktcap_lag")
    options_secondary <- breakpoint_options(
      n_portfolios = row$breakpoints_secondary,
      breakpoint_exchanges = strsplit(
        row$breakpoints_exchanges,
        split = "\\|"
      )[[1]]
    )
  }

  # Remove dates with too few stocks to avoid errors in compute_portfolio_returns()
  min_portfolio_size <- 10
  sorting_data <- sorting_data |>
    group_by(date) |>
    filter(n() >= min_portfolio_size) |>
    ungroup()

  portfolio_returns <- compute_portfolio_returns(
    sorting_data,
    sorting_variables,
    sorting_method = row$sorting_method,
    rebalancing_month,
    options_main,
    options_secondary,
    min_portfolio_size = min_portfolio_size
  )

  long_short_return <- portfolio_returns |>
    tidyfinance::compute_long_short_returns(direction = row$direction) |>
    pivot_longer(-date, names_to = "ret_type", values_to = "ret") |>
    mutate(
      id = row$id,
      ret_type = gsub("ret_excess_", "", ret_type),
      sorting_variable = row$sorting_variable,
      ret = replace_na(ret, 0)
    ) |>
    select(id, sorting_variable, date, ret_type, ret)

  long_short_return |>
    group_by(id) |>
    write_dataset(
      path = "data/portfolio_returns",
      format = "parquet",
      existing_data_behavior = "overwrite"
    )

  invisible(NULL)
}

# Paralellization --------------------------------------------------------

# Use all cores on the SLURM node. Adjust if memory is tight —
# each worker gets a copy of sorting_data_cache via future globals.

if (!is.na(Sys.getenv("SLURM_ARRAY_TASK_ID"))) {
  n_cores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "4"))
  plan(multisession, workers = n_cores)
} else {
  # NOTE: multicore uses forked processes that have shared memory, but only
  # works on Unix / macOS; change it to sequential on Windows (very slow though)
  plan(multicore, workers = availableCores())
}

grid_rows <- split(grid, seq_len(nrow(grid)))

future_walk(
  grid_rows,
  \(row) process_task(row, sorting_data_cache),
  .options = furrr_options(
    globals = c("process_task", "sorting_data_cache", "data_folder"),
    packages = c("dplyr", "tidyr", "arrow", "tidyfinance", "here")
  ),
  .progress = TRUE
)
