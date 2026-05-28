#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rsconnect)
})

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

message("Dashboard deployed: ", deployment$url)
