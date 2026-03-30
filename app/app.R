library(shiny)
library(duckplyr)
library(ggplot2)
library(scales)

# ---------------------------------------------------------------------------
# Sorting variable metadata
# ---------------------------------------------------------------------------
sv_info <- tibble::tribble(
  ~sorting_variable, ~full_name,                                ~direction,
  "52w",  "52-Week High",                            "top_minus_bottom",
  "aci",  "Abnormal Corporate Investment",           "bottom_minus_top",
  "ag",   "Asset Growth",                            "bottom_minus_top",
  "ami",  "Amihud Illiquidity",                      "top_minus_bottom",
  "beta", "Beta",                                    "top_minus_bottom",
  "bm",   "Book-to-Market",                          "top_minus_bottom",
  "cbop", "Cash-Based Operating Profitability",      "top_minus_bottom",
  "cdi",  "Composite Debt Issuance",                 "bottom_minus_top",
  "cfm",  "Cash Flow to Market",                     "top_minus_bottom",
  "csi",  "Composite Share Issuance",                "bottom_minus_top",
  "dbe",  "Change in Common Equity",                 "bottom_minus_top",
  "dcol", "Change in Current Operating Liabilities", "bottom_minus_top",
  "dfnl", "Change in Financial Liabilities",         "bottom_minus_top",
  "dinv", "Inventory Changes",                       "bottom_minus_top",
  "dm",   "Debt to Market",                          "top_minus_bottom",
  "dnoa", "Change in Net Operating Assets",          "bottom_minus_top",
  "dpia", "Change in PPE and Intangibles",           "bottom_minus_top",
  "dtv",  "Dollar Trading Volume",                   "bottom_minus_top",
  "dwc",  "Change in Working Capital",               "bottom_minus_top",
  "ebm",  "Enterprise Book to Market",               "top_minus_bottom",
  "em",   "Earnings to Market",                      "top_minus_bottom",
  "gpa",  "Gross Profits to Assets",                 "top_minus_bottom",
  "hr",   "Hiring Rate",                             "bottom_minus_top",
  "ig",   "Investment Growth",                       "bottom_minus_top",
  "iskew","Idiosyncratic Skewness",                  "bottom_minus_top",
  "ivol", "Idiosyncratic Volatility",                "bottom_minus_top",
  "mdr",  "Maximum Daily Return",                    "bottom_minus_top",
  "me",   "Market Equity",                           "bottom_minus_top",
  "mom",  "Momentum",                                "top_minus_bottom",
  "ndf",  "Net Debt Financing",                      "bottom_minus_top",
  "ndm",  "Net Debt to Market",                      "bottom_minus_top",
  "nef",  "Net Equity Financing",                    "bottom_minus_top",
  "noa",  "Net Operating Assets",                    "bottom_minus_top",
  "npy",  "Net Payout Yield",                        "top_minus_bottom",
  "nxf",  "Net External Financing",                  "bottom_minus_top",
  "o",    "O-Score",                                 "bottom_minus_top",
  "oa",   "Operating Accruals",                      "bottom_minus_top",
  "ocm",  "Operating Cash Flow to Market",           "top_minus_bottom",
  "ol",   "Operating Leverage",                      "top_minus_bottom",
  "ope",  "Operating Efficiency",                    "top_minus_bottom",
  "rer",  "Real-Estate Ratio",                       "top_minus_bottom",
  "rev",  "Long-Term Reversal",                      "bottom_minus_top",
  "rmom", "Residual Momentum",                       "top_minus_bottom",
  "roa",  "Return on Assets",                        "top_minus_bottom",
  "roe",  "Return on Equity",                        "top_minus_bottom",
  "rs",   "Relative Strength",                       "top_minus_bottom",
  "sm",   "Sales to Market",                         "top_minus_bottom",
  "sue",  "Standardized Unexpected Earnings",        "top_minus_bottom",
  "tbi",  "Taxable Income to Book Income",           "bottom_minus_top",
  "tur",  "Share Turnover",                          "bottom_minus_top"
)

# Build named vector for selectize: value = "sv_bm", label = "bm (Book-to-Market)"
sv_choices <- setNames(
  paste0("sv_", sv_info$sorting_variable),
  paste0(sv_info$sorting_variable, " (", sv_info$full_name, ")")
)

# ---------------------------------------------------------------------------
# Setup: download grid from HuggingFace (small, ~2 MB)
# ---------------------------------------------------------------------------
CACHE_DIR <- file.path(tempdir(), "factor_library_cache")
dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)

download_cached <- function(url, filename) {
  path <- file.path(CACHE_DIR, filename)
  if (!file.exists(path)) download.file(url, path, mode = "wb", quiet = TRUE)
  path
}

grid_url <- paste0(
  "https://huggingface.co/datasets/tidy-finance/factor-library-grid/",
  "resolve/refs%2Fconvert%2Fparquet/default/train/0000.parquet"
)
grid_path <- download_cached(grid_url, "grid.parquet")
grid <- duckplyr_df_from_parquet(grid_path) |> collect()

# ---------------------------------------------------------------------------
# Color palette (Wes Anderson Zissou1, via tidy-finance.org)
# ---------------------------------------------------------------------------
tf_colors <- c("#3B9AB2FF", "#78B7C5FF", "#EBCC2AFF", "#E1AF00FF", "#F21A00FF")
tf_primary   <- tf_colors[1]  # teal
tf_secondary <- tf_colors[5]  # red
tf_accent    <- tf_colors[3]  # yellow
tf_muted     <- tf_colors[2]  # light blue

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- fluidPage(
  tags$head(tags$style(HTML(sprintf("
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; }
    h2 { color: %s; }
    .sidebar { background-color: #f8f9fa; }
    .btn-default { background-color: %s; color: white; border-color: %s; }
    .btn-default:hover { background-color: %s; color: white; border-color: %s; }
    a { color: %s; }
    a:hover { color: %s; }
    hr { border-top: 2px solid %s; }
  ", tf_primary,
     tf_primary, tf_primary,
     tf_secondary, tf_secondary,
     tf_primary, tf_secondary,
     tf_muted
  )))),

  titlePanel("Tidy Finance Factor Library"),

  p(
    "This app provides access to the factor library described in",
    tags$em("Uncertainty Everywhere"),
    "(Gruber, Kastner, Voigt, and Weiss, 2024).",
    "It covers 50 firm characteristics and over 400,000 high-minus-low",
    "portfolio return series constructed from different formation methods.",
    "Select a sorting variable and portfolio parameters below to explore",
    "the resulting return series.",
    "Data is fetched on demand from",
    tags$a("HuggingFace", href = "https://huggingface.co/datasets/tidy-finance/factor-library",
           target = "_blank"),
    "and cached locally for the session."
  ),

  hr(),

  sidebarLayout(
    sidebarPanel(
      selectizeInput("sorting_variable", "Sorting variable",
                     choices = sv_choices,
                     selected = sv_choices[["bm (Book-to-Market)"]],
                     options = list(placeholder = "Type to search...")),
      uiOutput("sv_detail"),
      hr(),
      radioButtons("sorting_variable_lag", "Lag",
                   c("3 months" = "3m", "6 months" = "6m",
                     "Fama-French style" = "ff"),
                   selected = "3m"),
      radioButtons("rebalancing", "Rebalancing",
                   c("Monthly" = "monthly", "Annual" = "annual"),
                   selected = "annual"),
      radioButtons("breakpoints_main", "Breakpoints",
                   c("Five" = 5, "Ten" = 10), selected = 10),
      radioButtons("sorting_method", "Sorting method",
                   c("Univariate" = "univariate",
                     "Bivariate (dependent)" = "bivariate-dependent",
                     "Bivariate (independent)" = "bivariate-independent"),
                   selected = "bivariate-dependent"),
      conditionalPanel(
        "input.sorting_method != 'univariate'",
        radioButtons("breakpoints_secondary", "Secondary breakpoints",
                     c("Two" = 2, "Five" = 5), selected = 2)
      ),
      radioButtons("breakpoints_exchanges", "Exchanges",
                   c("NYSE only" = "NYSE",
                     "All exchanges" = "AMEX|NASDAQ|NYSE"),
                   selected = "NYSE"),
      radioButtons("weighting_scheme", "Weighting",
                   c("Equal-weighted" = "EW", "Value-weighted" = "VW"),
                   selected = "VW"),
      radioButtons("exclude_size", "Exclude small firms?",
                   c("No" = 0, "Smallest 20%" = 0.2), selected = 0.2),
      checkboxInput("exclude_financials", "Exclude financials", FALSE),
      checkboxInput("exclude_utilities", "Exclude utilities", FALSE),
      checkboxInput("exclude_negative_earnings", "Exclude negative earnings", FALSE),
      hr(),
      downloadButton("download_csv", "Download CSV"),
      downloadButton("download_parquet", "Download Parquet")
    ),

    mainPanel(
      plotOutput("plot"),
      tableOutput("summary_table"),
      hr(),
      h4("Download via R"),
      p(
        "You can download this portfolio return series programmatically",
        "using the",
        tags$a("tidyfinance", href = "https://cran.r-project.org/package=tidyfinance",
               target = "_blank"),
        "R package:"
      ),
      uiOutput("code_snippet")
    )
  )
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {

  # Show sorting variable details

  output$sv_detail <- renderUI({
    req(input$sorting_variable)
    sv_key <- sub("^sv_", "", input$sorting_variable)
    info <- sv_info |> filter(sorting_variable == sv_key)
    req(nrow(info) > 0)

    direction_label <- if (info$direction == "top_minus_bottom") {
      "Long top, short bottom"
    } else {
      "Long bottom, short top"
    }

    tags$div(
      style = sprintf(
        "background-color: %s20; border-left: 3px solid %s; padding: 8px 12px; border-radius: 4px; font-size: 0.9em;",
        tf_primary, tf_primary
      ),
      tags$strong(info$full_name),
      tags$br(),
      tags$span(
        style = "color: #666;",
        paste("HML direction:", direction_label)
      )
    )
  })

  matched_id <- reactive({
    grid |>
      filter(
        sorting_variable == input$sorting_variable,
        sorting_variable_lag == input$sorting_variable_lag,
        rebalancing == input$rebalancing,
        breakpoints_main == as.numeric(input$breakpoints_main),
        sorting_method == input$sorting_method,
        breakpoints_exchanges == input$breakpoints_exchanges,
        weighting_scheme == input$weighting_scheme,
        exclude_size == as.numeric(input$exclude_size),
        exclude_financials == input$exclude_financials,
        exclude_utilities == input$exclude_utilities,
        exclude_negative_earnings == input$exclude_negative_earnings
      ) |>
      filter(if (input$sorting_method != "univariate") {
        breakpoints_secondary == as.numeric(input$breakpoints_secondary)
      } else {
        TRUE
      }) |>
      head(1) |>
      pull(id)
  })

  factor_data <- reactive({
    req(length(matched_id()) > 0)

    sv <- sub("^sv_", "", input$sorting_variable)
    lag <- input$sorting_variable_lag
    cache_file <- paste0(sv, "_", lag, ".parquet")

    url <- sprintf(
      "https://huggingface.co/datasets/tidy-finance/factor-library/resolve/main/factor-library/sorting_variable=%s/sorting_variable_lag=%s/part-0.parquet",
      sv, lag
    )

    target_id <- matched_id()

    withProgress(message = "Fetching data...", {
      path <- download_cached(url, cache_file)
      duckplyr_df_from_parquet(path) |>
        filter(id == target_id) |>
        arrange(date, ret_type) |>
        collect()
    })
  })

  output$code_snippet <- renderUI({
    sv <- sub("^sv_", "", input$sorting_variable)

    args <- c(
      sprintf('sorting_variable = "%s"', sv),
      sprintf('sorting_variable_lag = "%s"', input$sorting_variable_lag),
      sprintf('rebalancing = "%s"', input$rebalancing),
      sprintf('breakpoints_main = %s', input$breakpoints_main),
      sprintf('sorting_method = "%s"', input$sorting_method),
      sprintf('breakpoints_exchanges = "%s"', input$breakpoints_exchanges),
      sprintf('weighting_scheme = "%s"', input$weighting_scheme),
      sprintf('exclude_size = %s', input$exclude_size),
      sprintf('exclude_financials = %s', toupper(input$exclude_financials)),
      sprintf('exclude_utilities = %s', toupper(input$exclude_utilities)),
      sprintf('exclude_negative_earnings = %s', toupper(input$exclude_negative_earnings))
    )

    if (input$sorting_method != "univariate") {
      args <- c(args, sprintf('breakpoints_secondary = %s', input$breakpoints_secondary))
    }

    code <- paste0(
      "library(tidyfinance)\n\n",
      "download_data(\n",
      '  "tidyfinance", "factor_library",\n',
      paste0("  ", args, collapse = ",\n"),
      "\n)"
    )

    tags$pre(
      style = sprintf(
        "background-color: %s15; border: 1px solid %s40; padding: 12px; border-radius: 4px; font-size: 0.85em; overflow-x: auto;",
        tf_primary, tf_primary
      ),
      tags$code(code)
    )
  })

  # Resolve the full name for the current sorting variable
  sv_full_name <- reactive({
    sv_key <- sub("^sv_", "", input$sorting_variable)
    info <- sv_info |> filter(sorting_variable == sv_key)
    if (nrow(info) > 0) info$full_name else sv_key
  })

  output$plot <- renderPlot({
    req(nrow(factor_data()) > 0)
    factor_data() |>
      mutate(date = as.Date(date)) |>
      group_by(ret_type) |>
      arrange(date) |>
      mutate(cumret = cumprod(1 + ret) - 1) |>
      ggplot(aes(x = date, y = cumret, color = ret_type)) +
      geom_line(linewidth = 0.8) +
      scale_color_manual(
        values = c("ew" = tf_primary, "vw" = tf_secondary),
        labels = c("ew" = "Equal-weighted", "vw" = "Value-weighted")
      ) +
      scale_y_continuous(labels = percent) +
      scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
      labs(
        title = sprintf("Cumulative HML returns: %s", sv_full_name()),
        x = NULL, y = "Cumulative return", color = NULL
      ) +
      theme_minimal(base_size = 14) +
      theme(
        legend.position = "bottom",
        plot.title = element_text(color = tf_primary, face = "bold"),
        panel.grid.minor = element_blank(),
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
  })

  output$summary_table <- renderTable({
    req(nrow(factor_data()) > 0)
    factor_data() |>
      mutate(
        Weighting = ifelse(ret_type == "ew", "Equal-weighted", "Value-weighted")
      ) |>
      group_by(Weighting) |>
      summarise(
        `Start date` = as.character(min(date)),
        `End date` = as.character(max(date)),
        Observations = n(),
        `Mean return` = sprintf("%.2f%%", mean(ret) * 100),
        `Std. dev.` = sprintf("%.2f%%", sd(ret) * 100),
        `Sharpe ratio` = sprintf("%.2f", mean(ret) / sd(ret) * sqrt(12)),
        Minimum = sprintf("%.2f%%", min(ret) * 100),
        Maximum = sprintf("%.2f%%", max(ret) * 100),
        .groups = "drop"
      )
  }, striped = TRUE, hover = TRUE, bordered = TRUE)

  output$download_csv <- downloadHandler(
    filename = function() sprintf("factor_id_%s.csv", matched_id()),
    content = function(file) write.csv(factor_data(), file, row.names = FALSE)
  )

  output$download_parquet <- downloadHandler(
    filename = function() sprintf("factor_id_%s.parquet", matched_id()),
    content = function(file) duckplyr_df_to_parquet(factor_data(), file)
  )
}

shinyApp(ui, server)
