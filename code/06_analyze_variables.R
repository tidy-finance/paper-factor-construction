library(dplyr)
library(tidyselect)
library(tidyr)
library(arrow)
library(ggplot2)
library(patchwork)


# Data loading
sv_lag_ff <- read_parquet("data/sorting_variables_lag_ff.parquet")
sv_lag_3m <- read_parquet("data/sorting_variables_lag_3m.parquet")
sv_lag_6m <- read_parquet("data/sorting_variables_lag_6m.parquet")

# Function to analyze a single sorting variable across different lags
analyze_sorting_variable <- function(sorting_variable) {
  sv_ff <- sv_lag_ff |>
    select(date, permno, all_of(sorting_variable)) |>
    rename(ff = all_of(sorting_variable))
  sv_3m <- sv_lag_3m |>
    select(date, permno, all_of(sorting_variable)) |>
    rename(m3 = all_of(sorting_variable))
  sv_6m <- sv_lag_6m |>
    select(date, permno, all_of(sorting_variable)) |>
    rename(m6 = all_of(sorting_variable))

  sv_combined <- sv_ff |>
    full_join(sv_3m, by = c("date", "permno")) |>
    full_join(sv_6m, by = c("date", "permno"))

  p1 <- sv_combined |>
    group_by(date) |>
    summarize(
      n_total = n(),
      n_ff_na = sum(is.na(ff)),
      n_3m_na = sum(is.na(m3)),
      n_6m_na = sum(is.na(m6))
    ) |>
    pivot_longer(
      cols = starts_with("n_"),
      names_to = "lag",
      values_to = "count"
    ) |>
    ggplot(aes(x = date, y = count, color = lag)) +
    geom_line() +
    facet_wrap(~lag, ncol = 2) +
    theme(legend.position = "none")

  p2 <- sv_combined |>
    group_by(date) |>
    summarize(across(
      c(ff, m3, m6),
      list(SD = \(x) sd(x, na.rm = TRUE)),
      .names = "{.col}_{.fn}"
    )) |>
    pivot_longer(
      cols = -date,
      names_to = c("variable", "stat"),
      names_sep = "_",
      values_to = "value"
    ) |>
    ggplot(aes(x = date, y = value, color = variable)) +
    geom_line() +
    facet_wrap(~variable, ncol = 2, scales = "fixed") +
    labs(title = "SD") +
    theme(legend.position = "none")

  p3 <- sv_combined |>
    group_by(date) |>
    summarize(
      across(
        c(ff, m3, m6),
        list(
          p10 = \(x) quantile(x, 0.10, na.rm = TRUE),
          p50 = \(x) quantile(x, 0.50, na.rm = TRUE),
          p90 = \(x) quantile(x, 0.90, na.rm = TRUE)
        ),
        .names = "{.col}_{.fn}"
      )
    ) |>
    pivot_longer(
      cols = -date,
      names_to = c("variable", "percentile"),
      names_sep = "_",
      values_to = "value"
    ) |>
    ggplot(aes(x = date, y = value, color = percentile)) +
    geom_line() +
    facet_wrap(~variable, ncol = 2, scales = "free_y")

  print(
    (p1 / p2 / p3) +
      plot_annotation(title = paste("Diagnostics for", sorting_variable))
  )

  if (
    tolower(readline("Enter [q] to quit, anything else to continue: ")) == "q"
  ) {
    return(TRUE)
  }
  return(FALSE)
}

# Loop through all sorting variables and analyze them
sorting_variables <- sv_lag_ff |>
  select(starts_with("sv_")) |>
  colnames()

for (sv in sorting_variables) {
  analyze_sorting_variable(sv)
}
