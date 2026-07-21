FROM rocker/shiny:4.3.2

WORKDIR /app
COPY . /app

# rocker/shiny ships shiny-server, but we run the app directly with runApp
# so we control the port Render assigns via $PORT.
RUN R -e "if (!requireNamespace('shiny', quietly = TRUE)) stop('shiny package missing from base image')"

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 3838)))"]
