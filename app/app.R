library(shiny)
library(duckdb)
library(dplyr)
library(ggplot2)

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

con <- dbConnect(duckdb())

grid_url <- paste0(
  "https://huggingface.co/datasets/tidy-finance/factor-library-grid/",
  "resolve/refs%2Fconvert%2Fparquet/default/train/0000.parquet"
)
grid <- dbGetQuery(con, sprintf(
  "SELECT * FROM read_parquet('%s')", download_cached(grid_url, "grid.parquet")
))

dbDisconnect(con, shutdown = TRUE)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- fluidPage(
  titlePanel("Tidy Finance Factor Library"),

  sidebarLayout(
    sidebarPanel(
      selectInput("sorting_variable", "Sorting variable",
                  sort(unique(grid$sorting_variable))),
      radioButtons("sorting_variable_lag", "Lag",
                   c("3m", "6m", "ff"), selected = "3m"),
      radioButtons("rebalancing", "Rebalancing",
                   c("monthly", "annual"), selected = "annual"),
      radioButtons("breakpoints_main", "Breakpoints",
                   c(5, 10), selected = 10),
      radioButtons("sorting_method", "Sorting method",
                   c("univariate", "bivariate-dependent", "bivariate-independent"),
                   selected = "bivariate-dependent"),
      conditionalPanel(
        "input.sorting_method != 'univariate'",
        radioButtons("breakpoints_secondary", "Secondary breakpoints",
                     c(2, 5), selected = 2)
      ),
      radioButtons("breakpoints_exchanges", "Exchanges",
                   c("NYSE", "AMEX|NASDAQ|NYSE"), selected = "NYSE"),
      radioButtons("weighting_scheme", "Weighting",
                   c("EW", "VW"), selected = "VW"),
      radioButtons("exclude_size", "Exclude small firms?",
                   c("No" = 0, "Smallest 20%" = 0.2), selected = 0.2),
      checkboxInput("exclude_financials", "Exclude financials", FALSE),
      checkboxInput("exclude_utilities", "Exclude utilities", FALSE),
      checkboxInput("exclude_negative_earnings", "Exclude negative earnings", FALSE),
      hr(),
      downloadButton("download_csv", "Download CSV")
    ),

    mainPanel(
      textOutput("status"),
      plotOutput("plot"),
      tableOutput("summary")
    )
  )
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {
  con <- dbConnect(duckdb())
  onSessionEnded(function() dbDisconnect(con, shutdown = TRUE))

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

    withProgress(message = "Fetching data...", {
      path <- download_cached(url, cache_file)
      dbGetQuery(con, sprintf(
        "SELECT * FROM read_parquet('%s') WHERE id = %s ORDER BY date, ret_type",
        path, matched_id()
      ))
    })
  })

  output$status <- renderText({
    if (length(matched_id()) == 0) {
      "No matching portfolio found."
    } else {
      sprintf("Portfolio ID: %s (%s rows)", matched_id(), nrow(factor_data()))
    }
  })

  output$plot <- renderPlot({
    req(nrow(factor_data()) > 0)
    factor_data() |>
      mutate(date = as.Date(date)) |>
      group_by(ret_type) |>
      arrange(date) |>
      mutate(cumret = cumprod(1 + ret) - 1) |>
      ggplot(aes(x = date, y = cumret, color = ret_type)) +
      geom_line() +
      labs(x = NULL, y = "Cumulative return", color = "Weighting") +
      theme_minimal()
  })

  output$summary <- renderTable({
    req(nrow(factor_data()) > 0)
    factor_data() |>
      group_by(ret_type) |>
      summarise(
        Mean = mean(ret), SD = sd(ret),
        Sharpe = mean(ret) / sd(ret) * sqrt(12),
        Min = min(ret), Max = max(ret), N = n(),
        .groups = "drop"
      )
  })

  output$download_csv <- downloadHandler(
    filename = function() sprintf("factor_id_%s.csv", matched_id()),
    content = function(file) write.csv(factor_data(), file, row.names = FALSE)
  )
}

shinyApp(ui, server)
