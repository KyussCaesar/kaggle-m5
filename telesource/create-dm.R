#!/usr/bin/env Rscript

argv = commandArgs(TRUE)

features = c()
dates = c()

mode = function(x) {
  stop("data specified before --features or --dates")
}

for (arg in argv) {
  if (arg == "--features") {
    mode = function(x) features <<- append(features, x)
    next()
  }

  if (arg == "--dates") {
    mode = function(x) dates <<- append(dates, as.integer(x))
    next()
  }

  mode(arg)
}

features = sort(features)
dates = sort(dates)

sink(stderr())

cat("the following features have been requested:\n")
cat(paste("-", features), sep = "\n")
cat("\n")

cat("the following dates have been requested:\n")
cat(paste("-", as.character(dates)), sep = "\n")
cat("\n")

sink()

stop("testing")

