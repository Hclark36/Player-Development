# Use a UTF-8 locale so accented player names survive import and export.
if (!l10n_info()[["UTF-8"]]) {
  for (locale in c("en_US.UTF-8", "C.UTF-8", "English_United States.utf8")) {
    suppressWarnings(try(Sys.setlocale("LC_CTYPE", locale), silent = TRUE))
    if (l10n_info()[["UTF-8"]]) break
  }
}
if (!l10n_info()[["UTF-8"]]) stop("A UTF-8 locale is required to preserve player names.")
# Reads code chunks without editing or rendering the source notebook.
read_chunks <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  chunks <- list(); code <- character(); inside <- FALSE; label <- ""
  for (line in lines) {
    if (!inside && grepl("^```\\{r", line)) {
      inside <- TRUE; code <- character()
      label <- sub("^```\\{r\\s*([^,}]*).*$", "\\1", line)
    } else if (inside && grepl("^```\\s*$", line)) {
      chunks[[length(chunks) + 1L]] <- list(label = trimws(label), code = paste(code, collapse = "\n"))
      inside <- FALSE
    } else if (inside) code <- c(code, line)
  }
  chunks
}
write_dashboard <- function(payload) {
  template <- paste(readLines("dashboard/template.html", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, dataframe = "rows", digits = 7, na = "null", null = "null")
  # Prevent source data from closing the embedded JSON script element.
  json <- gsub("<", "\\u003c", json, fixed = TRUE)
  compressed <- tempfile(fileext = ".gz")
  con <- gzfile(compressed, "wb"); writeBin(charToRaw(enc2utf8(json)), con); close(con)
  json <- jsonlite::base64_enc(readBin(compressed, "raw", n = file.info(compressed)$size))
  unlink(compressed)
  marker <- "__DASHBOARD_DATA__"
  parts <- strsplit(template, marker, fixed = TRUE)[[1]]
  stopifnot(length(parts) == 2L)
  writeLines(paste0(parts[1], json, parts[2]), "dashboard/index.html", useBytes = TRUE)
  message("Built dashboard/index.html for ", length(payload$players), " players.")
}
if (!file.exists("dashboard/template.html")) stop("Run this script from the repository root.")
for (pkg in c("knitr", "jsonlite")) if (!requireNamespace(pkg, quietly = TRUE)) stop("Install package: ", pkg)
options(timeout = max(600, getOption("timeout")))
dir.create("dashboard", showWarnings = FALSE)

for (pkg in c("glmnet", "xgboost")) if (!requireNamespace(pkg, quietly = TRUE)) stop("Install package: ", pkg)
e <- new.env(parent = globalenv())
chunks <- read_chunks("PlayerDevelopment.Rmd")
# Execute the original calculations in an isolated environment, keeping the RMD intact.
# Charts and exports are omitted because this script writes its own dashboard.
for (chunk in chunks) {
  if (chunk$label %in% c("development-player-forecast-chart", "development-save-results")) next
  eval(parse(text = chunk$code), envir = e)
}
candidates <- e$forecast_candidates
candidates <- candidates[is.finite(candidates$fga) & candidates$fga >= e$minimum_current_attempts & is.finite(candidates$points_per_attempt), , drop = FALSE]
stopifnot(nrow(candidates) > 0L, !anyDuplicated(candidates$player_id))
pred <- as.numeric(predict(e$final_elastic_net, newx = e$prepare_final_predictors(candidates), s = e$best_lambda, type = "response"))
stopifnot(all(is.finite(pred)))
players <- lapply(seq_len(nrow(candidates)), function(i) {
  p <- candidates[i, ]
  history <- subset(e$development_data, player_id == p$player_id & season < e$forecast_year & is.finite(points_per_attempt))
  history <- history[order(history$season), ]
  list(id = as.character(p$player_id), name = as.character(p$player_name), previous = p$points_per_attempt,
       prediction = pred[i], change = 100*(pred[i]-p$points_per_attempt), attempts = p$fga,
       lower = max(0, pred[i]+e$residual_limits[1]), upper = min(3, pred[i]+e$residual_limits[2]),
       history = lapply(seq_len(nrow(history)), function(j) list(year = history$season[j], actual = history$points_per_attempt[j], attempts = history$fga[j])))
})
players <- players[order(vapply(players, function(p) p$name, character(1)))]
write_dashboard(list(kind = "development", title = "Player Development", built = as.character(Sys.Date()), default = as.character(e$player_id), players = players,
                    forecast_year = e$forecast_year, minimum_attempts = e$minimum_current_attempts,
                    metrics = e$final_test_comparison, bootstrap = e$bootstrap_comparison,
                    source_sha = unname(tools::md5sum("PlayerDevelopment.Rmd"))))
# Verify that the all-player calculation exactly reproduces the notebook's selected-player forecast.
selected <- which(candidates$player_id == e$player_id)
stopifnot(length(selected) == 1L, abs(pred[selected] - e$predicted_efficiency) < 1e-10)
