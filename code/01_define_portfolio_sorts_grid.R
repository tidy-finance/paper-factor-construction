library("dplyr")
library("tidyr")
library("tibble")
library("arrow")

sorting_variable_information <- tribble(
  ~sorting_variable , ~full_name                                , ~direction         , ~citation                         ,
  "mom"             , "Momentum"                                , "top_minus_bottom" , "\\cite{fama.1996}"               ,
  "rmom"            , "Residual Momentum"                       , "top_minus_bottom" , "\\cite{blitz.2011}"              ,
  "rs"              , "Relative Strength"                       , "top_minus_bottom" , "\\cite{jegadeesh.2006}"          ,
  "sue"             , "Standardized Unexpected Earnings"        , "top_minus_bottom" , "\\cite{foster.1984}"             ,
  "52w"             , "52-Week High"                            , "top_minus_bottom" , "\\cite{george.2004}"             ,
  "me"              , "Market Equity"                           , "bottom_minus_top" , "\\cite{banz.1981}"               ,
  "cbop"            , "Cash-Based Operating Profitability"      , "top_minus_bottom" , "\\cite{ball.2016}"               ,
  "gpa"             , "Gross Profits to Assets"                 , "top_minus_bottom" , "\\cite{novy-marx.2013}"          ,
  "o"               , "O-Score"                                 , "bottom_minus_top" , "\\cite{ohlson.1980,dichev.1998}" ,
  "ope"             , "Operating Efficiency"                    , "top_minus_bottom" , "\\cite{fama.2015}"               ,
  "roa"             , "Return on Assets"                        , "top_minus_bottom" , "\\cite{balakrishnan.2010}"       ,
  "roe"             , "Return on Equity"                        , "top_minus_bottom" , "\\cite{hou.2014}"                ,
  "tbi"             , "Taxable Income to Book Income"           , "bottom_minus_top" , "\\cite{lev.2004}"                ,
  "bm"              , "Book-to-Market"                          , "top_minus_bottom" , "\\cite{daniel.2006}"             ,
  "cfm"             , "Cash-Flow-to-Market"                     , "top_minus_bottom" , "\\cite{lakonishok.1994}"         ,
  "dm"              , "Debt-to-Market"                          , "top_minus_bottom" , "\\cite{bhandari.1988}"           ,
  "ebm"             , "Enterprise-Book-to-Market"               , "top_minus_bottom" , "\\cite{penman.2007}"             ,
  "em"              , "Earnings-to-Market"                      , "top_minus_bottom" , "\\cite{basu.1983}"               ,
  "ndm"             , "Net-Debt-to-Market"                      , "bottom_minus_top" , "\\cite{penman.2007}"             ,
  "npy"             , "Net Payout Yield"                        , "top_minus_bottom" , "\\cite{boudoukh.2007}"           ,
  "ocm"             , "Operating-Cash-Flow-to-Market"           , "top_minus_bottom" , "\\cite{desai.2004}"              ,
  "rev"             , "Long-Term Reversal"                      , "bottom_minus_top" , "\\cite{debondt.1985}"            ,
  "sm"              , "Sales-to-Market"                         , "top_minus_bottom" , "\\cite{barbee.1996}"             ,
  "aci"             , "Abnormal Corporate Investment"           , "bottom_minus_top" , "\\cite{titman.2004}"             ,
  "ag"              , "Asset Growth"                            , "bottom_minus_top" , "\\cite{cooper.2008}"             ,
  "dinv"            , "Inventory Changes"                       , "bottom_minus_top" , "\\cite{thomas.2002}"             ,
  "dnoa"            , "Change in Net Operating Assets"          , "bottom_minus_top" , "\\cite{hirshleifer.2004}"        ,
  "dpia"            , "Change in PPE and Intangibles"           , "bottom_minus_top" , "\\cite{lyandres.2008}"           ,
  "dwc"             , "Change in Working Capital"               , "bottom_minus_top" , "\\cite{richardson.2005}"         ,
  "ig"              , "Investment Growth"                       , "bottom_minus_top" , "\\cite{xing.2008}"               ,
  "noa"             , "Net Operating Assets"                    , "bottom_minus_top" , "\\cite{hirshleifer.2004}"        ,
  "oa"              , "Operating Accruals"                      , "bottom_minus_top" , "\\cite{sloan.1996}"              ,
  "cdi"             , "Composite Debt Issuance"                 , "bottom_minus_top" , "\\cite{lyandres.2008}"           ,
  "csi"             , "Composite Share Issuance"                , "bottom_minus_top" , "\\cite{daniel.2006}"             ,
  "dbe"             , "Change in Common Equity"                 , "bottom_minus_top" , "\\cite{richardson.2005}"         ,
  "dcol"            , "Change in Current Operating Liabilities" , "bottom_minus_top" , "\\cite{richardson.2005}"         ,
  "dfnl"            , "Change in Financial Liabilities"         , "bottom_minus_top" , "\\cite{richardson.2005}"         ,
  "ndf"             , "Net Debt Financing"                      , "bottom_minus_top" , "\\cite{baker.2006}"              ,
  "nef"             , "Net Equity Financing"                    , "bottom_minus_top" , "\\cite{baker.2006}"              ,
  "nxf"             , "Net External Financing"                  , "bottom_minus_top" , "\\cite{baker.2006}"              ,
  "hr"              , "Hiring Rate"                             , "bottom_minus_top" , "\\cite{belo.2014}"               ,
  "ol"              , "Operating Leverage"                      , "top_minus_bottom" , "\\cite{novy-marx.2011}"          ,
  "rer"             , "Real-Estate Ratio"                       , "top_minus_bottom" , "\\cite{titman.2004}"             ,
  "ami"             , "Amihud Illiquidity"                      , "top_minus_bottom" , "\\cite{amihud.2002}"             ,
  "beta"            , "Beta"                                    , "top_minus_bottom" , "\\cite{fama.1973}"               ,
  "dtv"             , "Dollar Trading Volume"                   , "bottom_minus_top" , "\\cite{brennan.1998}"            ,
  "iskew"           , "Idiosyncratic Skewness"                  , "bottom_minus_top" , "\\cite{bali.2016}"               ,
  "ivol"            , "Idiosyncratic Volatility"                , "bottom_minus_top" , "\\cite{ang.2006}"                ,
  "mdr"             , "Maximum Daily Return"                    , "bottom_minus_top" , "\\cite{bali.2011}"               ,
  "tur"             , "Share Turnover"                          , "bottom_minus_top" , "\\cite{datar.1998}"
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
