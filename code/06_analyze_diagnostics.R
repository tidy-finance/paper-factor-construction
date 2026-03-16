library(dplyr)
library(tidyr)
library(arrow)
library(ggplot2)

diagnostics <- read_parquet("data/task_diagnostics.parquet")

diagnostics |>
  summary()

# No task errors in subsample
diagnostics |>
  filter(is.na(cpr_elapsed_secs))

diagnostics |>
  arrange(-elapsed_secs)

diagnostics |>
  pivot_longer(c(elapsed_secs, cpr_elapsed_secs)) |>
  ggplot(aes(x = value, fill = name)) +
  geom_histogram(binwidth = 1, position = "identity", alpha = 0.4)

diagnostics |>
  mutate(share_cpr = cpr_elapsed_secs / elapsed_secs) |>
  ggplot(aes(x = share_cpr)) +
  geom_histogram(binwidth = 0.01)

diagnostics |>
  count(n_warnings)

# Example for warnings
diagnostics |>
  filter(n_warnings > 0) |>
  count(warnings) |>
  arrange(-n) |>
  slice(1) |>
  pull(warnings)

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


sorting_variables <- read_parquet("data/sorting_variables_lag_3m.parquet")

full_grid <- read_parquet("data/portfolio_sort_grid.parquet")

diagnostics |>
  left_join(full_grid) |>
  group_by(sorting_variable) |>
  summarize(n = n(), warnings = sum(n_warnings > 0)) |>
  mutate(share = warnings / n) |>
  arrange(desc(n))
