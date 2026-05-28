#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rsconnect)
})

args <- commandArgs(trailingOnly = TRUE)
if (any(args %in% c("-h", "--help"))) {
  cat(
    "Deploy the dashboard to shinyapps.io.\n\n",
    "Optional environment variables:\n",
    "  SHINYAPPS_ACCOUNT    shinyapps.io account name\n",
    "  SHINYAPPS_TOKEN      shinyapps.io token\n",
    "  SHINYAPPS_SECRET     shinyapps.io secret\n",
    "  SHINYAPPS_APP_NAME   app name, default fibrotarget-liver\n\n",
    "Usage:\n",
    "  Rscript scripts/deploy_shinyapps.R\n",
    sep = ""
  )
  quit(status = 0)
}

account <- Sys.getenv("SHINYAPPS_ACCOUNT")
token <- Sys.getenv("SHINYAPPS_TOKEN")
secret <- Sys.getenv("SHINYAPPS_SECRET")
app_name <- Sys.getenv("SHINYAPPS_APP_NAME", "fibrotarget-liver")

if (nzchar(account) && nzchar(token) && nzchar(secret)) {
  rsconnect::setAccountInfo(
    name = account,
    token = token,
    secret = secret
  )
}

accounts <- rsconnect::accounts()
if (nrow(accounts) == 0) {
  stop(
    "No shinyapps.io account is configured. Set SHINYAPPS_ACCOUNT, ",
    "SHINYAPPS_TOKEN, and SHINYAPPS_SECRET, or run rsconnect::setAccountInfo().",
    call. = FALSE
  )
}

deployment <- rsconnect::deployApp(
  appDir = "dashboard",
  appName = app_name,
  account = accounts$name[[1]],
  server = accounts$server[[1]],
  launch.browser = FALSE,
  forceUpdate = TRUE
)

deployment_url <- if (is.list(deployment) && !is.null(deployment$url)) {
  deployment$url
} else {
  sprintf(
    "https://%s.shinyapps.io/%s/",
    accounts$name[[1]],
    app_name
  )
}

message("Dashboard deployed: ", deployment_url)
