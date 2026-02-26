library(tidyverse)
library(arrow)

diagnostics <- read_parquet("data/task_diagnostics.parquet")

diagnostics |>
  summary()

# TODO: resolve task errors
# ~530 tasks jave no cpr_elapsed_secs because they error with the following:
# Caused by error in `findInterval()`: ! 'vec' must be sorted non-decreasingly and not contain NAs
# Examples: task 1, 2, 5, 6
diagnostics |>
  filter(is.na(cpr_elapsed_secs)) |>
  count(status) |>
  pull(status)

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
  filter(n_warnings > 1) |>
  count(warnings) |>
  arrange(-n) |>
  slice(1) |>
  pull(warnings)

# TODO: resolve warnings
# Caused by warning:\n! The number of portfolios differs from the specified
# parameter due to clusters\nin the sorting variable.
# The sorting variable is constant and only one portfolio is returned.
diagnostics |>
  mutate(
    cluster_warning = str_detect(warnings, "clusters\nin the sorting variable"),
    constant_warning = str_detect(warnings, "sorting variable is constant")
  ) |>
  count(cluster_warning, constant_warning)
