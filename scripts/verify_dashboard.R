if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install jsonlite first")
html <- paste(readLines("dashboard/index.html", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
start <- '<script id="data" type="application/octet-stream">'
json <- strsplit(html, start, fixed = TRUE)[[1]][2]
json <- strsplit(json, '</script>', fixed = TRUE)[[1]][1]
json <- rawToChar(memDecompress(jsonlite::base64_dec(json), type = "gzip"))
d <- jsonlite::fromJSON(json, simplifyVector = FALSE)
ids <- vapply(d$players, function(p) p$id, character(1))
stopifnot(length(ids) > 0L, !anyDuplicated(ids), !grepl("__DASHBOARD_DATA__", html, fixed = TRUE))
for (p in d$players) {
  stopifnot(p$attempts >= d$minimum_attempts, is.finite(p$prediction), is.finite(p$lower), is.finite(p$upper),
            p$lower <= p$prediction, p$prediction <= p$upper,
            abs(p$change - 100*(p$prediction - p$previous)) < 1e-4, length(p$history) > 0L)
}
message("PASS: eligible player counts, unique IDs, finite forecasts, intervals, and change calculations")
