library(shiny)
library(arrow)
library(dplyr)
library(ggplot2)
library(gt)

# Read necessary data
grid <- read_parquet("factor-library-data/portfolio_sort_grid.parquet")

sorting_variables <- grid |>
  select(sorting_variable) |>
  distinct() |>
  pull(sorting_variable)

dataset <- open_dataset(
  "factor-library-data/factor-returns",
  partition = 'sorting_variable'
)

ui <- fluidPage(
  # Title and description
  fluidRow(
    column(
      12,
      div(
        style = "padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;",
        titlePanel("Portfolio returns"),
        p(
          "This website is based on the article “Uncertainty everwhere” (Gruber, Kastner, Voigt, and Weiss, 2024). This paper constructs 50 characteristics and resulting high-minus-low portfolio returns with a total of 374.016 different portfolio formation methods. We provide access to the data, the underlying source code and a number of other resources. Please cite our paper if you are using this data."
        ),
        HTML(markdown::markdownToHTML(
          text = "Gruber, L., Kastner, G., Voigt, S., & Weiss, P. (2024). *Uncertainty Everywhere*. Working Paper.",
          fragment.only = TRUE
        ))
      )
    )
  ),

  # Selectable sorting variable
  fluidRow(
    column(
      12,
      div(
        style = "padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;",
        selectInput(
          inputId = "sorting_variable",
          label = "Select Sorting variable",
          choices = sorting_variables,
          selected = sorting_variables[1],
          multiple = FALSE
        ),
      )
    )
  ),

  # Sample formation section
  div(
    style = "padding: 20px; border: 1px solid #ddd; background-color: #f9f9f9;",
    fluidRow(
      h3("Sample formation"),
      column(
        3, # Radio button for exclude_size filter
        radioButtons(
          inputId = "exclude_size",
          label = "Exclude small firms?",
          choices = list(
            "Include all firms" = 0,
            "Exclude smallest 20% of all firms" = 0.2
          ),
          selected = 0.2
        )
      ),
      column(
        3, # Radio button for exclude_financials filter
        radioButtons(
          inputId = "exclude_financials",
          label = "Exclude Financials?",
          choices = list(
            "Include Financials" = FALSE,
            "Exclude Financials" = TRUE
          ),
          selected = FALSE
        )
      ),
      column(
        3, # Radio button for exclude_utilities filter
        radioButtons(
          inputId = "exclude_utilities",
          label = "Exclude Utilities?",
          choices = list(
            "Include Utilities" = FALSE,
            "Exclude Financials" = TRUE
          ),
          selected = FALSE
        )
      ),
      column(
        3, # Radio button for exclude_utilities filter
        # Radio button for exclude_negative_earnings filter
        radioButtons(
          inputId = "exclude_negative_earnings",
          label = "Exclude negative earnings?",
          choices = list(
            "Include negative earnings" = FALSE,
            "Exclude negative earnings" = TRUE
          ),
          selected = FALSE
        )
      )
    )
  ),

  # Portfolio formation section
  div(
    style = "padding: 20px; border: 1px solid #ddd; background-color: #f9f9f9;",
    fluidRow(
      h3("Portfolio formation"),

      column(
        3, # Radio button for sorting_variable_lag
        radioButtons(
          inputId = "sorting_variable_lag",
          label = "Sorting variable lag",
          choices = list(
            "3 Months" = "3m",
            "6 Months" = "6m",
            "Fama-French style" = "FF"
          ),
          selected = "3m"
        )
      ),
      column(
        3, # Radio button for rebalancing
        radioButtons(
          inputId = "rebalancing",
          label = "Rebalancing frequency",
          choices = list("Monthly" = "monthly", "Annual" = "annual"),
          selected = "annual"
        )
      ),
      column(
        3, # Radio button for breakpoints_main
        radioButtons(
          inputId = "breakpoints_main",
          label = "Breakpoints (main portfolio)",
          choices = list("Five" = 5, "Ten" = 10),
          selected = 10
        )
      )
    ),
    fluidRow(
      column(
        3, # Radio button for sorting_method
        radioButtons(
          inputId = "sorting_method",
          label = "Sorting method",
          choices = list(
            "univariate" = "univariate",
            "bivariate (dependend)" = "bivariate-dependent",
            "bivariate (independent" = "bivariate-independent"
          ),
          selected = "bivariate-dependent"
        )
      ),
      column(
        3, # Radio button for breakpoints_secondary
        conditionalPanel(
          condition = "input.sorting_method != 'univariate'",
          radioButtons(
            inputId = "breakpoints_secondary",
            label = "Breakpoints (secondary portfolio)",
            choices = list("Two" = 2, "Five" = 5),
            selected = 2
          ),
        )
      ),
      column(
        3, # Radio button for breakpoints_exchanges
        radioButtons(
          inputId = "breakpoints_exchanges",
          label = "Exchanges used to compute breakpoints",
          choices = list(
            "All listing exchanges" = "AMEX|NASDAQ|NYSE",
            "NYSE only" = "NYSE"
          ),
          selected = "NYSE"
        )
      ),
      column(
        3, # Radio button for weighting_scheme
        radioButtons(
          inputId = "weighting_scheme",
          label = "Portfolio weighting",
          choices = list("Equal weighting" = "EW", "Value weighting" = "VW"),
          selected = "VW"
        )
      )
    )
  ),

  # Output section
  div(
    style = "padding: 20px; border: 1px solid #ddd; background-color: #f0f8ff;",
    fluidRow(
      h3("Data"),
      column(6, plotOutput("dataset_plot")),
      column(6, gt_output("dataset_preview"))
    )
  ),

  # Download button
  fluidRow(
    div(
      style = "text-align: center; margin-top: 10px;",
      column(
        12,
        downloadButton("download_feather", "Download .feather"),
        h4("Provide a reference to alternative download with tidyfinance API")
      )
    )
  )
)

# Define the server
server <- function(input, output, session) {
  observeEvent(input$sorting_method, {
    if (input$sorting_method == "univariate") {
      updateRadioButtons(session, "breakpoints_secondary", selected = 5)
    }
  })

  # Reactively filter the dataset based on the selected sorting variable
  filtered_dataset <- reactive({
    grid_ID <- grid |>
      filter(
        sorting_variable == input$sorting_variable,
        exclude_financials == input$exclude_financials,
        exclude_utilities == input$exclude_utilities,
        exclude_negative_earnings == input$exclude_negative_earnings,
        exclude_size == input$exclude_size,
        rebalancing == input$rebalancing,
        weighting_scheme == input$weighting_scheme,
        breakpoints_exchanges == input$breakpoints_exchanges,
        sorting_variable_lag == input$sorting_variable_lag,
        breakpoints_main == input$breakpoints_main,
        sorting_method == input$sorting_method
      ) |>
      filter(
        if (input$sorting_method != "univariate") {
          breakpoints_secondary == input$breakpoints_secondary
        } else {
          TRUE
        }
      ) |>
      head(1) |>
      pull(ID)

    dataset |> filter(ID == grid_ID) |> collect()
  })

  output$dataset_plot <- renderPlot({
    filtered_dataset() |>
      ggplot(aes(x = date, y = ret)) +
      geom_line() +
      labs(x = NULL, y = "Return") +
      theme_minimal()
  })

  output$dataset_preview <- filtered_dataset() |>
    summarise(
      start_date = min(date),
      max_date = max(date),
      periods = n(),
      mean = mean(ret),
      vola = sd(ret)
    ) |>
    mutate(sharpe = mean / vola) |>
    gt() |>
    fmt_number(columns = c(mean, vola, sharpe), decimals = 2) |>
    render_gt()

  # Offer filtered dataset as a Feather file for download
  output$download_feather <- downloadHandler(
    filename = function() {
      paste(
        "portfolio_reaturns_",
        filtered_dataset() |> head(1) |> pull(ID),
        ".feather",
        sep = ""
      )
    },
    content = function(file) {
      # Write the filtered dataset as a Feather file
      write_feather(filtered_dataset(), file)
    }
  )
}


# Run the app
shinyApp(ui = ui, server = server)
