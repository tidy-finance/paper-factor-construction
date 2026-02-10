library(dplyr)
library(tidyr)
library(tibble)
library(here)
library(arrow)

source("factor-library-code/00_global_options.R")

# TODO: either add sv_me here or remove from all scripts
sorting_variable_information <- tribble(
  ~sorting_variable , ~full_name                                , ~direction         ,
  "mom"             , "Momentum"                                , "top_minus_bottom" ,
  "rmom"            , "Residual Momentum"                       , "top_minus_bottom" ,
  "rs"              , "Relative Strength"                       , "top_minus_bottom" ,
  "sue"             , "Standardized Unexpected Earnings"        , "top_minus_bottom" ,
  "52w"             , "52-Week High"                            , "top_minus_bottom" ,
  "me"              , "Market Equity"                           , "bottom_minus_top" ,
  "cbop"            , "Cash-Based Operating Profitability"      , "top_minus_bottom" ,
  "gpa"             , "Gross Profit Asset"                      , "top_minus_bottom" ,
  "o"               , "Operating Leverage"                      , "bottom_minus_top" ,
  "ope"             , "Operating Efficiency"                    , "top_minus_bottom" ,
  "roa"             , "Return on Assets"                        , "top_minus_bottom" ,
  "roe"             , "Return on Equity"                        , "top_minus_bottom" ,
  "tbi"             , "Total Accruals to Book Income"           , "bottom_minus_top" ,
  "bm"              , "Book-to-Market"                          , "top_minus_bottom" ,
  "cfm"             , "Cash Flow to Market"                     , "top_minus_bottom" ,
  "dm"              , "Dividend to Market"                      , "top_minus_bottom" ,
  "ebm"             , "Earnings-to-Book-to-Market"              , "top_minus_bottom" ,
  "em"              , "Earnings to Market"                      , "top_minus_bottom" ,
  "ndm"             , "Net Debt to Market"                      , "bottom_minus_top" ,
  "npy"             , "Net Payout Yield"                        , "top_minus_bottom" ,
  "ocm"             , "Operating Cash Flow to Market"           , "top_minus_bottom" ,
  "rev"             , "Reversals"                               , "bottom_minus_top" ,
  "sm"              , "Sales to Market"                         , "top_minus_bottom" ,
  "aci"             , "Accruals"                                , "bottom_minus_top" ,
  "ag"              , "Asset Growth"                            , "bottom_minus_top" ,
  "dinv"            , "Change in Inventory"                     , "bottom_minus_top" ,
  "dnoa"            , "Change in Net Operating Assets"          , "bottom_minus_top" ,
  "dpia"            , "Change in PPE and Intangibles"           , "bottom_minus_top" ,
  "dwc"             , "Change in Working Capital"               , "bottom_minus_top" ,
  "ig"              , "Investment Growth"                       , "bottom_minus_top" ,
  "noa"             , "Net Operating Assets"                    , "bottom_minus_top" ,
  "oa"              , "Order Accruals"                          , "bottom_minus_top" ,
  "cdi"             , "Change in Debt and Issuance"             , "bottom_minus_top" ,
  "csi"             , "Change in Shares Issued"                 , "bottom_minus_top" ,
  "dbe"             , "Change in Book Equity"                   , "bottom_minus_top" ,
  "dcol"            , "Change in Current Operating Liabilities" , "bottom_minus_top" ,
  "dfnl"            , "Change in Financial Liabilities"         , "bottom_minus_top" ,
  "ndf"             , "Net Debt Financing"                      , "bottom_minus_top" ,
  "nef"             , "Net Equity Financing"                    , "bottom_minus_top" ,
  "nxf"             , "Net External Financing"                  , "bottom_minus_top" ,
  "hr"              , "Hiring Rate"                             , "bottom_minus_top" ,
  "ol"              , "Operating Leverage"                      , "top_minus_bottom" ,
  "rer"             , "Revenue Reversals"                       , "top_minus_bottom" ,
  "ami"             , "Asset Maturity Index"                    , "top_minus_bottom" ,
  "beta"            , "Beta"                                    , "top_minus_bottom" ,
  "dtv"             , "Debt-to-Value"                           , "bottom_minus_top" ,
  "iskew"           , "Idiosyncratic Skewness"                  , "bottom_minus_top" ,
  "ivol"            , "Idiosyncratic Volatility"                , "bottom_minus_top" ,
  "mdr"             , "Maximum Daily Return"                    , "bottom_minus_top" ,
  "tur"             , "Turnover"                                , "bottom_minus_top"
)

write_parquet(
  sorting_variable_information,
  here(
    data_folder,
    "sorting_variable_information.parquet"
  )
)

full_grid <- expand_grid(
  sorting_variable = unique(sorting_variable_information$sorting_variable),
  exclude_size = c(0, 0.2),
  exclude_financials = c(TRUE, FALSE),
  exclude_utilities = c(TRUE, FALSE),
  exclude_negative_earnings = c(TRUE, FALSE),
  sorting_variable_lag = c("3m", "6m", "FF"),
  rebalancing = c("monthly", "annual"),
  breakpoints_main = c(5, 10),
  sorting_method = c(
    "univariate",
    "bivariate-dependent",
    "bivariate-independent"
  ),
  breakpoints_secondary = c(2, 5),
  breakpoints_exchanges = c("NYSE", "AMEX|NASDAQ|NYSE"),
  weighting_scheme = c("EW", "VW")
)

# Revise breakpoints_secondary
# TODO: comment should say why this is happening
grid <- full_grid |>
  filter(
    !(sorting_method == "univariate" &
      breakpoints_secondary > min(full_grid$breakpoints_secondary))
  ) |>
  mutate(
    breakpoints_secondary = if_else(
      sorting_method == "univariate",
      NA_real_,
      breakpoints_secondary
    )
  )

# Revise sv_me's double sorts
# TODO: comment should say why this is happening
# TODO: sv_me is not part of sorting_variable_information
grid <- grid |>
  filter(
    !(sorting_variable == "sv_me" &
      sorting_method %in% c("bivariate-dependent", "bivariate-independent"))
  )

# Revise sv_em and exclude_negative_earnings combination
# TODO: redundant as long as sv_me is not part of sorting_variable_information
grid <- grid |>
  filter(!(sorting_variable == "sv_em" & exclude_negative_earnings == FALSE))

grid <- grid |>
  arrange(sorting_variable_lag, sorting_variable) |>
  rowid_to_column(var = "id")

write_parquet(
  grid,
  here(
    data_folder,
    "portfolio_sort_grid.parquet"
  )
)
