library(dplyr)
library(tidyr)
library(lubridate)
library(tidyfinance)
library(arrow)

compustat_annual <- open_dataset("data/compustat_annual.parquet")

crsp_monthly <- open_dataset("data/crsp_monthly.parquet")

# Add relevant CRSP items
compustat_annual <- compustat_annual |>
  left_join(
    crsp_monthly |>
      select(gvkey, permno, date, mktcap, siccd),
    join_by(gvkey, date),
    relationship = "one-to-one"
  ) |>
  collect()

compustat_annual <- compustat_annual |>
  mutate(
    int_td = replace_na(dlc, 0) + replace_na(dltt, 0),
    int_td = if_else(int_td <= 0, NA_real_, int_td),
    int_col = lct - replace_na(dlc, 0),
    int_fnl = if_else(
      if_all(c(dlc, dltt, pstk), is.na),
      NA_real_,
      replace_na(dlc, 0) +
        replace_na(dltt, 0) +
        replace_na(pstk, 0)
    ),
    int_rer = if_else(
      datadate < ymd("1984-01-01"),
      (ppenb + ppenls) / ppent,
      (fatb + fatl) / ppegt
    ),
    int_sic_2 = substr(siccd, 0, 2),
    # Minimum sales threshold to avoid extreme capex/sales ratios
    int_ce = if_else(sale >= 10, capx / sale, NA_real_),
    int_noa = (at - che) -
      (at -
        replace_na(dlc, 0) -
        replace_na(dltt, 0) -
        replace_na(mib, 0) -
        replace_na(pstk, 0) -
        ceq),
    int_wc = act - che - lct + replace_na(dlc, 0),
    int_oa_helper = act - che - lct + replace_na(dlc, 0) + replace_na(txp, 0),
    int_o_1 = log(at),
    int_o_2 = (dlc + dltt) / at,
    int_o_3 = (act - lct) / at,
    int_o_4 = lct / at,
    int_o_5 = as.numeric(lt > at),
    int_o_6 = ni / at,
    int_o_7 = (pi + dp) / lt,
    int_o_ni_negative = as.numeric(ni < 0),
    int_op = revt -
      replace_na(cogs, 0) -
      replace_na(xsga, 0) -
      replace_na(xint, 0),
    int_be = coalesce(seq, ceq + pstk, at - lt, NA_real_) +
      coalesce(txditc, txdb + itcb, 0) -
      coalesce(pstkrv, pstkl, pstk, 0),
    int_netdebt = dltt +
      dlc +
      pstk +
      replace_na(dvpa, 0) -
      replace_na(tstkp, 0) -
      che,
    int_ebm_numerator = int_netdebt +
      ceq +
      replace_na(tstkp, 0) -
      replace_na(dvpa, 0),
    int_ebm_denominator = int_netdebt + mktcap
  ) |>
  rename(int_me = mktcap)

# Lag certain variables
compustat_annual <- compustat_annual |>
  add_lag_columns(
    c(
      "ceq",
      "at",
      "emp",
      "ppegt",
      "invt",
      "capx",
      "ni",
      "pstkrv",
      "act",
      "che",
      "lct",
      "dlc",
      "revt",
      "xpp",
      "drc",
      "drlt",
      "ap",
      "xacc",
      "wcap",
      "int_ce",
      "int_col",
      "int_fnl",
      "int_noa",
      "int_wc",
      "int_oa_helper",
      "int_o_ni_negative"
    ),
    lag = years(1),
    by = "gvkey"
  ) |>
  # Append "1" to lag suffix to indicate 1-year lag (e.g., ceq_lag -> ceq_lag1)
  rename_with(ends_with("_lag"), .fn = ~ paste0(.x, "1"))

## Two year lag
compustat_annual <- compustat_annual |>
  add_lag_columns(
    "int_ce",
    lag = years(2),
    by = "gvkey"
  ) |>
  rename(int_ce_lag2 = int_ce_lag)

## Three year lag
compustat_annual <- compustat_annual |>
  add_lag_columns(
    "int_ce",
    lag = years(3),
    by = "gvkey"
  ) |>
  rename(int_ce_lag3 = int_ce_lag)

## Five year lag
compustat_annual <- compustat_annual |>
  add_lag_columns(
    "int_td",
    lag = years(5),
    by = "gvkey"
  ) |>
  rename(int_td_lag5 = int_td_lag)

# Create industry averages
compustat_annual_industry <- compustat_annual |>
  select(year, int_sic_2, int_rer) |>
  drop_na() |>
  group_by(year, int_sic_2) |>
  summarize(
    # Minimum firms per industry-year for meaningful industry average
    int_rer_industry = if_else(n() >= 5, mean(int_rer), NA_real_),
    .groups = "drop"
  )

# Merge back
compustat_annual <- compustat_annual |>
  left_join(
    compustat_annual_industry,
    join_by(year, int_sic_2),
    relationship = "many-to-one"
  )

# Sorting variables -------------------------------------------------------

# Financing & issuance
sorting_variables_yearly <- compustat_annual |>
  mutate(
    sv_cdi = log(int_td) - log(int_td_lag5),
    sv_dbe = (ceq - ceq_lag1) / at_lag1,
    sv_dcol = (int_col - int_col_lag1) / at_lag1,
    sv_dfnl = (int_fnl - int_fnl_lag1) / at_lag1,
    sv_ndf = (dltis - dltr + replace_na(dlcch, 0)) / (1 / 2 * (at + at_lag1)),
    sv_nef = (sstk - prstkc - dv) / (1 / 2 * (at + at_lag1)),
    sv_nxf = sv_ndf + sv_nef
  ) |>

  # Growth & labor
  mutate(
    sv_hr = (emp - emp_lag1) / (1 / 2 * (emp + emp_lag1)),
    sv_ol = (cogs + xsga) / at,
    sv_rer = int_rer - int_rer_industry,
    sv_aci = int_ce / (1 / 3 * (int_ce_lag1 + int_ce_lag2 + int_ce_lag3)) - 1,
    sv_ag = (at - at_lag1) / at_lag1,
    sv_dnoa = (int_noa - int_noa_lag1) / at_lag1,
    sv_dpia = ((ppegt - ppegt_lag1) + (invt - invt_lag1)) / at_lag1,
    sv_dwc = (int_wc - int_wc_lag1) / at_lag1,
    sv_ig = (capx - capx_lag1) / capx_lag1,
    sv_dinv = (invt - invt_lag1) / (1 / 2 * (at + at_lag1)),
    sv_noa = int_noa / at_lag1,
    sv_oa = if_else(
      year < 1988,
      (int_oa_helper - int_oa_helper_lag1 - dp) / at_lag1,
      (ni - oancf) / at_lag1
    )
  ) |>

  # Profitability
  mutate(
    sv_cbop = (revt -
      cogs -
      xsga +
      replace_na(xrd, 0) -
      replace_na(revt - revt_lag1, 0) -
      replace_na(invt - invt_lag1, 0) -
      replace_na(xpp - xpp_lag1, 0) +
      replace_na(drc - drc_lag1, 0) +
      replace_na(drlt - drlt_lag1, 0) +
      replace_na(ap - ap_lag1, 0) +
      replace_na(xacc - xacc_lag1, 0)) /
      at,
    sv_gpa = (revt - cogs) / at,
    sv_o = -1.32 -
      0.407 * int_o_1 +
      6.030 * int_o_2 -
      1.430 * int_o_3 +
      0.076 * int_o_4 -
      1.720 * int_o_5 -
      2.370 * int_o_6 -
      1.830 * int_o_7 +
      0.285 * as.numeric(int_o_ni_negative & int_o_ni_negative_lag1) -
      0.521 * winsorize((ni - ni_lag1) / (abs(ni) + abs(ni_lag1)), 0.01),
    sv_ope = int_op / int_be,
    sv_tbi = if_else(pi > 0 & ni > 0, pi / ni, NA_real_)
  ) |>

  # Valuation
  mutate(
    sv_bm = int_be / int_me,
    sv_cfm = if_else((ib + dp) > 0, (ib + dp) / int_me, NA_real_),
    sv_dm = (dlc + dltt) / int_me,
    sv_ebm = if_else(
      (int_ebm_numerator > 0) & (int_ebm_denominator > 0),
      int_ebm_numerator / int_ebm_denominator,
      NA_real_
    ),
    sv_em = if_else(ib > 0, ib / int_me, NA_real_),
    sv_ndm = int_netdebt / int_me,
    sv_npy = ((dvc +
      prstkc +
      if_else((pstkrv - pstkrv_lag1) < 0, (pstkrv - pstkrv_lag1), 0)) -
      (sstk - if_else((pstkrv - pstkrv_lag1) > 0, (pstkrv - pstkrv_lag1), 0))) /
      int_me,
    sv_ocm = if_else(
      year < 1988,
      (fopt - (wcap - wcap_lag1)) / int_me,
      oancf / int_me
    ),
    sv_sm = sale / int_me,
    filter_earnings = ib
  )

# Remove Inf, NaN, and sign-convention exclusions
sorting_variables_yearly <- sorting_variables_yearly |>
  mutate(
    # Zero hiring rate typically indicates missing employment data
    sv_hr = na_if(sv_hr, 0),
    # Negative net payout yield indicates net issuance; excluded by construction
    sv_npy = if_else(sv_npy < 0, NA_real_, sv_npy),
    # Negative operating cash flow to market excluded by construction
    sv_ocm = if_else(sv_ocm < 0, NA_real_, sv_ocm)
  ) |>
  mutate(
    across(starts_with("sv_"), ~ if_else(is.finite(.x), .x, NA_real_))
  )

sorting_variables_yearly <- sorting_variables_yearly |>
  select(gvkey, date, starts_with("filter_"), starts_with("sv_"))

write_parquet(sorting_variables_yearly, "data/sorting_variables_yearly.parquet")
