library(arrow)

source("code/00_global_options.R")

open_dataset(file.path(data_folder, "portfolio_returns")) |>
  Scanner$create() |>
  as_record_batch_reader() |>
  write_dataset(
    file.path(data_folder, "factor-library"),
    partition = "sorting_variable"
  )
