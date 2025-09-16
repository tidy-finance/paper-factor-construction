# Record sorting variables' directions


# Packages ----------------------------------------------------------------
library(arrow)

source("00_global_options.R")


# Record directions -------------------------------------------------------
sv_directions <- tibble::tribble(
  ~sorting_variable,         ~direction,
  "sv_mom", "top_minus_bottom",
  "sv_rmom", "top_minus_bottom",
  "sv_rs", "top_minus_bottom",
  "sv_sue", "top_minus_bottom",
  "sv_52w", "top_minus_bottom",
  "sv_me", "bottom_minus_top",
  "sv_cbop", "top_minus_bottom",
  "sv_gpa", "top_minus_bottom",
  "sv_o", "bottom_minus_top",
  "sv_ope", "top_minus_bottom",
  "sv_roa", "top_minus_bottom",
  "sv_roe", "top_minus_bottom",
  "sv_tbi", "top_minus_bottom",
  "sv_bm", "top_minus_bottom",
  "sv_cfm", "top_minus_bottom",
  "sv_dm", "top_minus_bottom",
  "sv_ebm", "top_minus_bottom",
  "sv_em", "top_minus_bottom",
  "sv_ndm", "bottom_minus_top",
  "sv_npy", "top_minus_bottom",
  "sv_ocm", "top_minus_bottom",
  "sv_rev", "bottom_minus_top",
  "sv_sm", "top_minus_bottom",
  "sv_aci", "bottom_minus_top",
  "sv_ag", "bottom_minus_top",
  "sv_dinv", "bottom_minus_top",
  "sv_dnoa", "bottom_minus_top",
  "sv_dpia", "bottom_minus_top",
  "sv_dwc", "bottom_minus_top",
  "sv_ig", "bottom_minus_top",
  "sv_noa", "bottom_minus_top",
  "sv_oa", "bottom_minus_top",
  "sv_cdi", "bottom_minus_top",
  "sv_csi", "bottom_minus_top",
  "sv_dbe", "bottom_minus_top",
  "sv_dcol", "bottom_minus_top",
  "sv_dfnl", "bottom_minus_top",
  "sv_ndf", "bottom_minus_top",
  "sv_nef", "bottom_minus_top",
  "sv_nxf", "bottom_minus_top",
  "sv_hr", "bottom_minus_top",
  "sv_ol", "top_minus_bottom",
  "sv_rer", "top_minus_bottom",
  "sv_ami", "top_minus_bottom",
  "sv_beta", "top_minus_bottom",
  "sv_dtv", "bottom_minus_top",
  "sv_iskew", "bottom_minus_top",
  "sv_ivol", "bottom_minus_top",
  "sv_mdr", "bottom_minus_top",
  "sv_tur", "bottom_minus_top"
)

# Save --------------------------------------------------------------------
sv_directions |> write_feather(paste0(data_raw_folder, "sv_directions.feather"))
