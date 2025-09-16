library(arrow)
library(dplyr)
library(stringr)
library(forcats)

grid <- read_feather("data_raw/portfolio_sort_grid.feather")
portfolio_returns <- open_dataset("data_raw/portfolio_returns",
                                  partition = "sorting_variable",
                                  format = "feather")

portfolio_returns |> 
  write_dataset("data/portfolio_returns", partition = "sorting_variable")