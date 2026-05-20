library("dplyr")
library("tidyr")
library("arrow")
library("ggplot2")

diagnostics <- read_parquet("data/task_diagnostics.parquet")

diagnostics |>
  summary()

# No task errors in subsample
diagnostics |>
  count(status)

diagnostics |>
  count(n_warnings)

# "The number of portfolios differs from the specified parameter due to cluster in the sorting variable."
# "The sorting variable is constant and only one portfolio is returned." -> never occurs?
diagnostics |>
  mutate(
    has_errored = status != "success",
    cluster_warning = stringr::str_detect(
      warnings,
      "clusters"
    ),
    constant_warning = stringr::str_detect(
      warnings,
      "constant"
    )
  ) |>
  filter(cluster_warning) |>
  count(has_errored, cluster_warning, constant_warning)

full_grid <- read_parquet("data/portfolio_sort_grid.parquet")

diagnostics |>
  left_join(full_grid) |>
  group_by(sorting_variable) |>
  summarize(n = n(), warnings = sum(n_warnings > 0)) |>
  mutate(share = warnings / n) |>
  arrange(desc(n))
