library(dplyr)
library(tidyr)
library(arrow)
library(ggplot2)

diagnostics <- read_parquet("data/task_diagnostics.parquet")

diagnostics |>
  summary()

# No task errors in subsample
diagnostics |>
  filter(is.na(cpr_elapsed_secs)) |>
  count(status) |>
  pull(status)

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
  filter(n_warnings > 1) |>
  count(warnings) |>
  arrange(-n) |>
  slice(1) |>
  pull(warnings)

# TODO: resolve warnings - maybe we should not compute portfolio returns for
# these cases?
# "The number of portfolios differs from the specified parameter due to clusters\nin the sorting variable."
# "The sorting variable is constant and only one portfolio is returned."
diagnostics |>
  mutate(
    has_errored = status != "success",
    cluster_warning = stringr::str_detect(
      warnings,
      "clusters\nin the sorting variable"
    ),
    constant_warning = stringr::str_detect(
      warnings,
      "sorting variable is constant"
    )
  ) |>
  count(has_errored, cluster_warning, constant_warning)
