library(arrow)
library(dplyr)
library(stringr)
library(forcats)

open_dataset(
  "data_raw/portfolio_returns",
  partition = "sorting_variable"
) |>
  write_dataset("data/portfolio_returns", partition = "sorting_variable")
