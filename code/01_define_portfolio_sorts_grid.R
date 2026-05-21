library("dplyr")
library("tidyr")
library("tibble")
library("arrow")

sorting_variable_information <- tribble(
  ~sorting_variable , ~full_name                                , ~direction         ,
  "mom"             , "Momentum"                                , "top_minus_bottom" ,
  "rmom"            , "Residual Momentum"                       , "top_minus_bottom" ,
  "rs"              , "Relative Strength"                       , "top_minus_bottom" ,
  "sue"             , "Standardized Unexpected Earnings"        , "top_minus_bottom" ,
  "52w"             , "52-Week High"                            , "top_minus_bottom" ,
  "me"              , "Market Equity"                           , "bottom_minus_top" ,
  "cbop"            , "Cash-Based Operating Profitability"      , "top_minus_bottom" ,
  "gpa"             , "Gross Profits to Assets"                 , "top_minus_bottom" ,
  "o"               , "O-Score"                                 , "bottom_minus_top" ,
  "ope"             , "Operating Efficiency"                    , "top_minus_bottom" ,
  "roa"             , "Return on Assets"                        , "top_minus_bottom" ,
  "roe"             , "Return on Equity"                        , "top_minus_bottom" ,
  "tbi"             , "Taxable Income to Book Income"           , "bottom_minus_top" ,
  "bm"              , "Book-to-Market"                          , "top_minus_bottom" ,
  "cfm"             , "Cash-Flow-to-Market"                     , "top_minus_bottom" ,
  "dm"              , "Debt-to-Market"                          , "top_minus_bottom" ,
  "ebm"             , "Enterprise-Book-to-Market"               , "top_minus_bottom" ,
  "em"              , "Earnings-to-Market"                      , "top_minus_bottom" ,
  "ndm"             , "Net-Debt-to-Market"                      , "bottom_minus_top" ,
  "npy"             , "Net Payout Yield"                        , "top_minus_bottom" ,
  "ocm"             , "Operating-Cash-Flow-to-Market"           , "top_minus_bottom" ,
  "rev"             , "Long-Term Reversal"                      , "bottom_minus_top" ,
  "sm"              , "Sales-to-Market"                         , "top_minus_bottom" ,
  "aci"             , "Abnormal Corporate Investment"           , "bottom_minus_top" ,
  "ag"              , "Asset Growth"                            , "bottom_minus_top" ,
  "dinv"            , "Inventory Changes"                       , "bottom_minus_top" ,
  "dnoa"            , "Change in Net Operating Assets"          , "bottom_minus_top" ,
  "dpia"            , "Change in PPE and Intangibles"           , "bottom_minus_top" ,
  "dwc"             , "Change in Working Capital"               , "bottom_minus_top" ,
  "ig"              , "Investment Growth"                       , "bottom_minus_top" ,
  "noa"             , "Net Operating Assets"                    , "bottom_minus_top" ,
  "oa"              , "Operating Accruals"                      , "bottom_minus_top" ,
  "cdi"             , "Composite Debt Issuance"                 , "bottom_minus_top" ,
  "csi"             , "Composite Share Issuance"                , "bottom_minus_top" ,
  "dbe"             , "Change in Common Equity"                 , "bottom_minus_top" ,
  "dcol"            , "Change in Current Operating Liabilities" , "bottom_minus_top" ,
  "dfnl"            , "Change in Financial Liabilities"         , "bottom_minus_top" ,
  "ndf"             , "Net Debt Financing"                      , "bottom_minus_top" ,
  "nef"             , "Net Equity Financing"                    , "bottom_minus_top" ,
  "nxf"             , "Net External Financing"                  , "bottom_minus_top" ,
  "hr"              , "Hiring Rate"                             , "bottom_minus_top" ,
  "ol"              , "Operating Leverage"                      , "top_minus_bottom" ,
  "rer"             , "Real-Estate Ratio"                       , "top_minus_bottom" ,
  "ami"             , "Amihud Illiquidity"                      , "top_minus_bottom" ,
  "beta"            , "Beta"                                    , "top_minus_bottom" ,
  "dtv"             , "Dollar Trading Volume"                   , "bottom_minus_top" ,
  "iskew"           , "Idiosyncratic Skewness"                  , "bottom_minus_top" ,
  "ivol"            , "Idiosyncratic Volatility"                , "bottom_minus_top" ,
  "mdr"             , "Maximum Daily Return"                    , "bottom_minus_top" ,
  "tur"             , "Share Turnover"                          , "bottom_minus_top"
)

write_parquet(
  sorting_variable_information,
  "data/sorting_variable_information.parquet"
)

full_grid <- expand_grid(
  sorting_variable = paste0(
    "sv_",
    unique(sorting_variable_information$sorting_variable)
  ),
  min_size_quantile = c(NA, 0.2),
  exclude_financials = c(TRUE, FALSE),
  exclude_utilities = c(TRUE, FALSE),
  exclude_negative_earnings = c(TRUE, FALSE),
  sorting_variable_lag = c("3m", "6m", "ff"),
  rebalancing = c("monthly", "annual"),
  n_portfolios_main = c(3, 5, 10),
  sorting_method = c(
    "univariate",
    "bivariate-dependent",
    "bivariate-independent"
  ),
  breakpoints_min_size_threshold = c(NA, 0.2),
  n_portfolios_secondary = c(2, 5),
  breakpoints_exchanges = c("NYSE", "AMEX|NASDAQ|NYSE"),
  weighting_scheme = c("EW", "VW", "capped VW")
)

grid <- full_grid |>
  # For univariate sorting, secondary breakpoints do not apply
  filter_out(when_all(
    sorting_method == "univariate",
    n_portfolios_secondary > min(full_grid$n_portfolios_secondary)
  )) |>
  mutate(
    n_portfolios_secondary = if_else(
      sorting_method == "univariate",
      NA_real_,
      n_portfolios_secondary
    )
  ) |>
  # sv_me is excluded from bivariate sorts (size already in first sort)
  filter_out(when_all(
    sorting_variable == "sv_me",
    sorting_method %in% c("bivariate-dependent", "bivariate-independent")
  )) |>
  # sv_em cannot be combined with allowing negative earnings
  filter_out(when_all(
    sorting_variable == "sv_em",
    exclude_negative_earnings == FALSE
  )) |>
  # id is used for parallelization later
  arrange(sorting_variable_lag, sorting_variable) |>
  rowid_to_column(var = "id")

write_parquet(
  grid,
  "data/portfolio_sort_grid.parquet"
)
