# Set global options
library(dplyr)
library(tidyr)
library(arrow)

# Dates -------------------------------------------------------------------
date_start_data <- as.Date("1960-01-01")
date_end_data <- as.Date("2022-12-31") # limited to 2023-11-01 by macro data for our project

date_start_returns <- as.Date("1973-07-01")
date_end_returns <- as.Date("2022-12-31")

date_evaluation_split_2thirds <- as.Date("2006-01-01")
date_evaluation_split_1half <- as.Date("1998-01-01")

# Naming ------------------------------------------------------------------
# PAF = factors constructed with methodological variation
# PF = factors as obtained from Open Source Asset Pricing
# Unconditional = static models
# Conditional = dynamic models

label_factors_paf <- "Path-augmented factors"
label_factors_pf <- "Published factors"
label_model_unconditional <- "Unconditional model"
label_model_conditional <- "Conditional model"

mapping_nodes <- tibble(
  node = c(
    "exclude_size",
    "exclude_financials",
    "exclude_utilities",
    "exclude_negative_earnings",
    "sorting_variable_lag",
    "rebalancing",
    "breakpoints_main",
    "sorting_method",
    "breakpoints_secondary",
    "breakpoints_exchanges",
    "weighting_scheme"
  ),
  node_label = c(
    "Exclusion (size)",
    "Exclusion (financials)",
    "Exclusion (utilities)",
    "Exclusion (neg. earnings)",
    "Sorting variable (lag)",
    "Rebalancing frequency",
    "Breakpoints (primary)",
    "Sorting method",
    "Breakpoints (secondary)",
    "Breakpoints (Listing exchange)",
    "Weighting scheme"
  ),
  node_order = 1:11
)

relabel_paths <- function(data) {
  data |>
    mutate(
      exclude_size = if_else(exclude_size == 0, "No", "Yes (20%)"),
      exclude_financials = if_else(exclude_financials, "Yes", "No"),
      exclude_utilities = if_else(exclude_utilities, "Yes", "No"),
      exclude_negative_earnings = if_else(
        exclude_negative_earnings,
        "Yes",
        "No"
      ),
      sorting_variable_lag = sorting_variable_lag,
      rebalancing = if_else(rebalancing == "monthly", "Monthly", "Annual"),
      sorting_method = case_when(
        sorting_method == "univariate" ~ "Univariate",
        sorting_method == "bivariate-independent" ~ "Bivariate (indep.)",
        sorting_method == "bivariate-dependent" ~ "Bivariate (dep.)",
        .default = NA
      ),
      breakpoints_secondary = breakpoints_secondary,
      breakpoints_exchanges = if_else(
        breakpoints_exchanges == "NYSE",
        "NYSE",
        "AMEX, NASDAQ & NYSE"
      ),
      weighting_scheme = weighting_scheme
    )
}

# Colors ------------------------------------------------------------------
color_paf_hex <- "#4682b4"
color_pf_hex <- "#b47846"

color_palette <- c(
  "#1B9E77",
  "#D95F02",
  "#7570B3",
  "#E7298A",
  "#66A61E",
  "#E6AB02",
  "#A6761D",
  "#666666"
)

# Raw database ------------------------------------------------------------
data_raw_folder <- "data_raw/"

# Helper functions --------------------------------------------------------
# Rolling SD -----
compute_rolling_sd <- function(data, column, quarters, min_obs) {
  rolling_sd <- slider::slide_period_vec(
    .x = data |> pull({{ column }}),
    .i = data$date,
    .period = "quarter",
    .f = ~ if_else(sum(!is.na(.x)) < min_obs, NA_real_, sd(.x, na.rm = TRUE)),
    .before = quarters - 1,
    .complete = FALSE
  )

  return(rolling_sd)
}


# Lagged values -----
add_lagged_values <- function(
  original_data,
  new_data,
  id_keys,
  id_date = "date",
  min_lag,
  max_lag,
  ff_adjustment = FALSE
) {
  new_column_names <- new_data |>
    select(-all_of(c(id_keys, id_date))) |>
    names()

  if (ff_adjustment) {
    new_data <- new_data |>
      mutate(
        ..year = year(.data[[id_date]]),
        ..lower_bound = floor_date(.data[[id_date]], unit = "year") %m+%
          min_lag,
        ..upper_bound = ..lower_bound %m+% max_lag
      )
  } else {
    new_data <- new_data |>
      mutate(
        ..lower_bound = .data[[id_date]] %m+% min_lag,
        ..upper_bound = ..lower_bound %m+% max_lag
      )
  }

  for (column_name in new_column_names) {
    if (ff_adjustment) {
      tmp_data <- new_data |>
        select(
          ..lower_bound,
          ..upper_bound,
          ..year,
          all_of(c(id_keys, id_date, column_name))
        ) |>
        tidyr::drop_na(!!!column_name) |>
        group_by(.data[[id_keys]], ..year) |>
        slice_max(.data[[id_date]], n = 1) |>
        ungroup() |>
        select(-all_of(id_date))
    } else {
      tmp_data <- new_data |>
        select(..lower_bound, ..upper_bound, all_of(c(id_keys, column_name))) |>
        tidyr::drop_na(!!!column_name)
    }

    column_values <- original_data |>
      select(..date := all_of(id_date), everything()) |>
      left_join(
        tmp_data,
        join_by(
          !!!id_keys,
          closest(..date >= ..lower_bound),
          ..date < ..upper_bound
        )
      ) |>
      select(all_of(column_name)) |>
      pull()

    original_data <- original_data |>
      mutate("{column_name}" := column_values)
  }

  return(original_data)
}


# Bayesian posterior parameter values -----
compute_posterior_parameters <- function(
  factor_returns,
  test_assets,
  bayesian_model = TRUE,
  macro_predictors = NULL,
  tau = 2
) {
  ## OLS estimates
  periods = nrow(test_assets)
  N = ncol(test_assets)
  K = ncol(factor_returns)
  Z = matrix(rep(1, periods), dimnames = list(NULL, "constant"))
  M = 0

  if (!is.null(macro_predictors)) {
    # dynamic model
    M = ncol(macro_predictors)
    Z = cbind(constant = 1, macro_predictors)
  }

  X = matrix(nrow = periods, ncol = (K + 1) * (M + 1))
  colnames(X) = names(kronecker(
    Z[1, ],
    cbind(alpha = 1, factor_returns)[1, ],
    make.dimnames = TRUE
  ))
  for (t in 1:periods) {
    X[t, ] = kronecker(Z[t, ], cbind(alpha = 1, factor_returns)[t, ])
  }

  phi = solve(t(X) %*% X) %*% t(X) %*% test_assets

  X_restricted = factor_returns # zero intercept regression
  colnames(X_restricted) = paste0("constant:", colnames(X_restricted))
  phi_restricted = solve(t(X_restricted) %*% X_restricted) %*%
    t(X_restricted) %*%
    test_assets
  missing_variables = setdiff(rownames(phi), rownames(phi_restricted))
  phi_restricted = rbind(
    phi_restricted,
    matrix(
      data = 0,
      nrow = length(missing_variables),
      ncol = ncol(test_assets),
      dimnames = list(missing_variables)
    )
  )
  phi_restricted = phi_restricted[rownames(phi), ]

  shrinkage_constant = 0 # benchmark case (OLS)

  if (bayesian_model) {
    # compute shrinkage constant (IA.98)

    mu_mkt = factor_returns[, "mkt_excess"] |> mean()
    var_mkt = factor_returns[, "mkt_excess"] |> var()

    mu_factors = colMeans(factor_returns)
    sigma_factors = cov(factor_returns)

    sr_market_sq = (mu_mkt^2) / var_mkt
    sr_max_sq = as.numeric(
      t(mu_factors) %*% solve(sigma_factors) %*% mu_factors
    )

    t0 = N * (1 + M) * (1 + sr_max_sq) / ((tau^2 - 1) * sr_market_sq)
    shrinkage_constant = t0 / (t0 + periods)
  }

  return(shrinkage_constant * phi_restricted + (1 - shrinkage_constant) * phi) # IA.24
}


# Compute expected returns -----
compute_expected_returns <- function(
  factor_returns,
  risk_premia = NULL,
  macro_predictors = NULL,
  test_assets = NULL,
  bayesian_model = FALSE,
  tau = 2,
  cutoff_date = NULL
) {
  # Filter, remove dates, and create matrices
  if (is.Date(cutoff_date)) {
    # cutoff case
    periods_oos = nrow(
      compute_sample_split(cutoff_date, sample = factor_returns)$oos_data
    ) # Compute first
    factor_returns <- compute_sample_split(
      cutoff_date,
      sample = factor_returns
    )$is_data
    if (is.null(risk_premia)) {
      risk_premia <- colMeans(factor_returns)
    }
    if (!is.null(macro_predictors)) {
      macro_predictors_is <- compute_sample_split(
        cutoff_date,
        sample = macro_predictors
      )$is_data
      macro_predictors_oos <- compute_sample_split(
        cutoff_date,
        sample = macro_predictors
      )$oos_data
    } else {
      # no macro predictors
      macro_predictors_is <- NULL
      macro_predictors_oos <- NULL
    }
    if (!is.null(test_assets)) {
      test_assets <- compute_sample_split(
        cutoff_date,
        sample = test_assets
      )$is_data
    }
  } else {
    factor_returns <- factor_returns |> select(-date) |> as.matrix()
    periods_oos = nrow(factor_returns)
    if (is.null(risk_premia)) {
      risk_premia <- colMeans(factor_returns)
    }
    if (!is.null(macro_predictors)) {
      macro_predictors <- macro_predictors |> select(-date) |> as.matrix()
    }
    if (!is.null(test_assets)) {
      test_assets <- test_assets |> select(-date) |> as.matrix()
    }
  }

  risk_premia = t(c(alpha = 1, risk_premia))

  phi <- compute_posterior_parameters(
    factor_returns = factor_returns,
    test_assets = test_assets,
    bayesian_model = bayesian_model,
    macro_predictors = macro_predictors_is,
    tau = tau
  )

  if (!is.null(macro_predictors)) {
    # dynamic model
    Z = cbind(constant = 1, macro_predictors_oos)
  } else {
    # static model
    Z = matrix(rep(1, periods_oos), dimnames = list(NULL, "constant"))
  }

  risk_premia_matrix = kronecker(Z, risk_premia, make.dimnames = TRUE)
  predicted_returns = risk_premia_matrix %*% phi

  return(predicted_returns)
}

# Performance metrics -----
compute_performance_metrics <- function(
  predicted_returns,
  asset_returns,
  cutoff_date = NULL
) {
  if (is.Date(cutoff_date)) {
    asset_returns <- compute_sample_split(
      cutoff_date,
      sample = asset_returns
    )$oos_data
  } else {
    asset_returns <- asset_returns |> select(-date) |> as.matrix()
  }

  errors <- asset_returns - predicted_returns

  static_oracle_errors <- scale(asset_returns, scale = FALSE)

  mape <- mean(abs(errors)) - mean(abs(static_oracle_errors))
  rmse <- 100 * (sqrt(mean(errors^2)) - sqrt(mean(static_oracle_errors^2)))
  r_squared <- 100 * (1 - sum(errors^2) / sum(asset_returns^2))
  return(tibble(rmse, r_squared))
}


# Compute sample split in IS and OOS  -----
compute_sample_split <- function(cutoff_date, sample) {
  if (is.Date(cutoff_date) & is.Date(sample$date[1])) {
    is_data = sample |>
      filter(date < cutoff_date) |>
      select(-date) |>
      as.matrix()

    if (cutoff_date < max(sample$date)) {
      oos_data = sample |>
        filter(date >= cutoff_date) |>
        select(-date) |>
        as.matrix()
    } else {
      oos_data = is_data
    }

    return(list(is_data = is_data, oos_data = oos_data))
  } else {
    stop("No cutoff date supplied or missing date identifier.")
  }
}

# Compute efficient portfolio weights  -----
compute_sharpe_ratio <- function(sigma, mu, oos_returns, mvp_only = FALSE) {
  sigma_inv <- solve(sigma)
  w_efficient <- sigma_inv %*% mu
  if (mvp_only) {
    w_efficient <- sigma_inv %*% rep(1, nrow(sigma))
  }
  w_efficient <- w_efficient / sum(w_efficient)
  portfolio_returns <- oos_returns %*% w_efficient
  sharpe_ratio = sqrt(12) * mean(portfolio_returns) / sd(portfolio_returns)
  return(sharpe_ratio)
}

compute_model_implied_moments <- function(
  factor_returns,
  test_assets,
  macro_predictors,
  tau
) {
  periods = nrow(test_assets)
  N = ncol(test_assets)
  K = ncol(factor_returns)

  if (is.null(macro_predictors)) {
    M = 0
    Z = cbind(constant = rep(1, periods))
  } else {
    M = ncol(macro_predictors)
    Z = cbind(constant = 1, macro_predictors)
  }

  X = matrix(nrow = periods, ncol = (K + 1) * (M + 1))
  colnames(X) = names(kronecker(
    Z[1, ],
    cbind(alpha = 1, factor_returns)[1, ],
    make.dimnames = TRUE
  ))
  for (t in 1:periods) {
    X[t, ] = kronecker(Z[t, ], cbind(alpha = 1, factor_returns)[t, ])
  }

  phi = solve(t(X) %*% X) %*% t(X) %*% test_assets

  X_restricted = factor_returns # zero intercept regression
  colnames(X_restricted) = paste0("constant:", colnames(X_restricted))
  phi_restricted = solve(t(X_restricted) %*% X_restricted) %*%
    t(X_restricted) %*%
    test_assets
  missing_variables = setdiff(rownames(phi), rownames(phi_restricted))
  phi_restricted = rbind(
    phi_restricted,
    matrix(
      data = 0,
      nrow = length(missing_variables),
      ncol = ncol(test_assets),
      dimnames = list(missing_variables)
    )
  )
  phi_restricted = phi_restricted[rownames(phi), ]

  mu_mkt = factor_returns[, "mkt_excess"] |> mean()
  var_mkt = factor_returns[, "mkt_excess"] |> var()

  mu_factors = colMeans(factor_returns)
  sigma_factors = cov(factor_returns)

  sr_market_sq = (mu_mkt^2) / var_mkt
  sr_max_sq = as.numeric(t(mu_factors) %*% solve(sigma_factors) %*% mu_factors)

  t0 = N * (1 + M) * (1 + sr_max_sq) / ((tau^2 - 1) * (1 + sr_market_sq))
  shrinkage_constant = t0 / (t0 + periods)

  beta_coef <- shrinkage_constant *
    phi_restricted +
    (1 - shrinkage_constant) * phi
  final_period_beta <- kronecker(t(colMeans(Z)), diag(K + 1)) %*% beta_coef

  residuals <- test_assets - X %*% beta_coef

  Sigma_r = cov(residuals)
  w <- colMeans(X)
  variance_model <- Sigma_r *
    as.numeric((1 + t(w) %*% solve(t(X) %*% X) %*% w / shrinkage_constant))
  mu_model <- (100 * colMeans(X)) %*% beta_coef

  return(tibble(sigma = list(variance_model), mu = list(mu_model)))
}
