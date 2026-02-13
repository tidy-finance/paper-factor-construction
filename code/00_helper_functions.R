rolling_window_residual_to_sd <- function(data, months) {
  returns <- slide_period_vec(
    .x = data,
    .i = data$date,
    .period = "month",
    .f = ~ {
      if (nrow(.x) < months) {
        NA_real_
      } else {
        (prod(1 + .x$int_roll_residual) - 1) / sd(.x$int_roll_residual)
      }
    },
    .before = months - 1,
    .complete = FALSE
  )

  return(returns)
}

rolling_window_residual <- function(data, months) {
  residuals <- slide_period_vec(
    .x = data,
    .i = data$date,
    .period = "month",
    .f = ~ {
      complete <- drop_na(.x)
      if (nrow(complete) < months) {
        NA_real_
      } else {
        last(lm(ret_excess ~ mkt_excess + smb + hml, data = complete)$residuals)
      }
    },
    .before = months - 1,
    .complete = FALSE
  )

  return(residuals)
}

# Helper function to compute standardized quarterly variables
# TODO: create r-tidyfinance function
compute_standardized_variable <- function(
  data,
  variable_name,
  lag_variable_name,
  output_name,
  cluster,
  min_analysis_date
) {
  data |>
    mutate(
      temp_var = {{ variable_name }} - {{ lag_variable_name }}
    ) |>
    select(gvkey, date, temp_var) |>
    drop_na() |>
    arrange(gvkey, date) |>
    group_by(gvkey) |>
    multidplyr::partition(cluster) |>
    mutate(
      temp_sd = compute_rolling_sd(
        pick(everything()),
        column = temp_var,
        period = "quarter",
        periods = 8,
        min_obs = 6
      ),
      {{ output_name }} := temp_var / temp_sd,
      {{ output_name }} := if_else(
        date >= min_analysis_date,
        {{ output_name }},
        NA_real_
      )
    ) |>
    collect() |>
    ungroup() |>
    select(gvkey, date, {{ output_name }}) |>
    drop_na()
}


# TODO: replace this by a r-tidyfinance function (calculate_residuals()?)
calculate_residuals <- function(data, formula) {
  complete <- complete.cases(model.frame(
    formula,
    data = data,
    na.action = na.pass
  ))
  if (sum(complete) <= length(all.vars(formula))) {
    return(rep(NA_real_, nrow(data)))
  }
  res <- rep(NA_real_, nrow(data))
  res[complete] <- lm(formula, data = data[complete, ])$residuals
  res
}
