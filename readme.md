This is a quick and dirty analyzer for general partner compensation in private equity and real estate partnerships.  It allows a multi-tier compensation with multiple hurdles, partcipation and catchup structures.

Added a new Rmd file in July illustrating use of the waterfall function to analyze known gross return distributions.

### Interactive app

`app.R` wraps the `waterfall()` function (from `waterfallqd.r`) in a Shiny app where you can configure tiers of asset management fee, preferred return, catchup and carry, and see the resulting gross/net return curves and per-layer distribution detail.

To run locally:

```r
install.packages("shiny")
shiny::runApp()
```

### Deploying to Render

This repo includes a `Dockerfile` and `render.yaml` for deployment on [Render](https://render.com):

1. Push this repo to GitHub (already done if you're reading this on GitHub).
2. In Render, click **New +** → **Blueprint**, and point it at this repo. Render will read `render.yaml` and provision a Docker web service automatically.
   - Alternatively, choose **New +** → **Web Service**, select this repo, and set environment to **Docker** — Render will detect the `Dockerfile`.
3. The container installs R + Shiny, then runs `app.R`, listening on the `PORT` Render assigns.