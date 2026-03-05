library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(ggplot2)
library(arrow)

# Investigate cross-sections of sorting variables

sorting_variable_data <- tibble(
  file_name = list.files("data", pattern = "sorting_variables_.*.parquet")
) |>
  mutate(
    data = map(file_name, ~ read_parquet(file.path("data", .))),
    file_name = str_remove(file_name, "sorting_variables_") |>
      str_remove(".parquet")
  )

missing_data <- sorting_variable_data |>
  mutate(
    data = map(
      data,
      ~ .x |>
        select(date, contains("sv_")) |>
        mutate(across(-date, is.na)) |>
        group_by(date) |>
        summarise(across(everything(), mean)) |>
        pivot_longer(-date, names_to = "sv", values_to = "proportion_missing")
    )
  ) |>
  unnest(data)

missing_data |>
  ggplot(aes(date, proportion_missing, group = sv)) +
  geom_point(size = 0.1) +
  facet_wrap(~file_name) +
  theme_minimal() +
  theme(legend.position = "none") +
  labs(
    title = "Proportion of Missing Data for Sorting Variables",
    x = "Date",
    y = "Proportion Missing",
    color = "Sorting Variable"
  )
