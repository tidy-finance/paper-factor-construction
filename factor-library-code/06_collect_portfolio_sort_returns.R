library(arrow)

open_dataset("data/portfolio_returns") |>
  Scanner$create() |>
  as_record_batch_reader() |>
  write_parquet("data/portfolio_returns.parquet")
