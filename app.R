library(shiny)

source("waterfallqd.r")

MAX_TIERS <- 6

ui <- fluidPage(
  titlePanel("GP Waterfall Compensation Analyzer"),
  sidebarLayout(
    sidebarPanel(
      helpText("Model a multi-tier GP/LP waterfall: preferred return, catchup and carry, ",
               "with an optional asset management fee at each layer."),
      numericInput("capital", "Capital called ($)", value = 102, min = 0),
      numericInput("invcost", "Investment cost ($)", value = 100, min = 0),
      fluidRow(
        column(6, numericInput("ret_min", "Min distribution ($)", value = 100)),
        column(6, numericInput("ret_max", "Max distribution ($)", value = 140))
      ),
      numericInput("ret_step", "Step size", value = 0.5, min = 0.01),
      hr(),
      numericInput("n_tiers", "Number of waterfall tiers", value = 1, min = 1, max = MAX_TIERS, step = 1),
      uiOutput("tier_inputs"),
      hr(),
      numericInput("query_amount", "Distribution amount to inspect ($)", value = 130)
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Return Curves",
                 plotOutput("returnPlot"),
                 plotOutput("marginalPlot")),
        tabPanel("Distribution Detail",
                 h4("Cash distributed by layer at the selected amount"),
                 tableOutput("detailTable"),
                 h4("Summary"),
                 tableOutput("summaryTable"))
      )
    )
  )
)

server <- function(input, output, session) {

  output$tier_inputs <- renderUI({
    n <- input$n_tiers
    if (is.null(n) || is.na(n) || n < 1) return(NULL)
    n <- min(max(round(n), 1), MAX_TIERS)

    defaults <- list(
      am = c(0, 0, 0, 0, 0, 0),
      pref = c(8, 12, 20, 25, 30, 35),
      catchup = c(50, 0, 0, 0, 0, 0),
      carry = c(20, 30, 50, 50, 50, 50)
    )

    rows <- lapply(seq_len(n), function(i) {
      wellPanel(
        strong(paste("Tier", i)),
        fluidRow(
          column(3, numericInput(paste0("am_", i), "AM fee ($)", value = defaults$am[i])),
          column(3, numericInput(paste0("pref_", i), "Pref (%)", value = defaults$pref[i])),
          column(3, numericInput(paste0("catchup_", i), "Catchup (%)", value = defaults$catchup[i], min = 0, max = 100)),
          column(3, numericInput(paste0("carry_", i), "Carry (%)", value = defaults$carry[i], min = 0, max = 100))
        )
      )
    })
    do.call(tagList, rows)
  })

  dmat <- reactive({
    n <- input$n_tiers
    req(n)
    n <- min(max(round(n), 1), MAX_TIERS)

    vals <- function(prefix, scale = 1) {
      sapply(seq_len(n), function(i) {
        v <- input[[paste0(prefix, "_", i)]]
        if (is.null(v) || is.na(v)) 0 else v / scale
      })
    }

    req(all(sapply(seq_len(n), function(i) !is.null(input[[paste0("pref_", i)]]))))

    data.frame(
      am = vals("am"),
      pref = vals("pref", 100) * input$capital,
      catchup = vals("catchup", 100),
      carry = vals("carry", 100)
    )
  })

  ans <- reactive({
    req(input$ret_min, input$ret_max, input$ret_step, input$capital, input$invcost)
    validate(
      need(input$ret_max > input$ret_min, "Max distribution must exceed min distribution"),
      need(input$ret_step > 0, "Step must be positive")
    )
    ret <- seq(input$ret_min, input$ret_max, by = input$ret_step)
    waterfall(dmat(), ret = ret, capital = input$capital, invcost = input$invcost)
  })

  output$returnPlot <- renderPlot({
    a <- ans()
    plot(a$grossreturn, a$grossreturn, type = 'l', col = 'red',
         xlab = 'Gross Return (%)', ylab = 'Return (%)', main = 'Gross vs Net Return')
    lines(a$grossreturn, a$netreturn, type = 'l', col = 'blue')
    legend('topleft', legend = c('Gross Return', 'Net Return'), col = c('red', 'blue'), lwd = 1)
  })

  output$marginalPlot <- renderPlot({
    a <- ans()
    validate(need(length(a$grossreturn) > 1, "Need at least two distribution points"))
    deltaprofit <- diff(a$grossreturn)
    deltagp <- diff(a$grossreturn - a$netreturn)
    gpcut <- 100 * deltagp / deltaprofit
    plot(a$grossreturn[-1], gpcut, type = 'l', col = 'blue',
         main = 'Marginal Share of Return to Sponsor',
         xlab = 'Gross Return (%)', ylab = 'Percent to GP (%)')
  })

  output$detailTable <- renderTable({
    a <- ans()
    q <- input$query_amount
    validate(need(!is.null(q) && !is.na(q), "Enter a distribution amount"))
    idx <- which.min(abs(a$grossreturn - (100 * (q - input$invcost) / input$invcost)))
    df <- data.frame(
      Layer = rownames(a$lpshare),
      LP = round(a$lpshare[, idx], 2),
      GP = round(a$gpshare[, idx], 2)
    )
    df
  }, rownames = FALSE)

  output$summaryTable <- renderTable({
    a <- ans()
    q <- input$query_amount
    validate(need(!is.null(q) && !is.na(q), "Enter a distribution amount"))
    idx <- which.min(abs(a$grossreturn - (100 * (q - input$invcost) / input$invcost)))
    data.frame(
      Metric = c("Gross Return (%)", "Net Return to LP (%)", "Total LP", "Total GP"),
      Value = c(
        round(a$grossreturn[idx], 2),
        round(a$netreturn[idx], 2),
        round(sum(a$lpshare[, idx]), 2),
        round(sum(a$gpshare[, idx]), 2)
      )
    )
  }, rownames = FALSE)
}

shinyApp(ui = ui, server = server)
