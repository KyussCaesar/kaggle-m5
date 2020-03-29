
suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
  library(dtplyr)
  library(dplyr)
  library(here)
  library(logging)
})

basicConfig()

#' Print an expression and it's value
#' Returns the value, invisibly
debugit = function(x) {
  var = deparse(substitute(x))
  val = eval(x)
  loginfo(paste(var, "=", val))
  invisible(val)
}

#' Return the cardinality (number of unique elements in) x.
cardinality = function(x) length(unique(x))

#' Return the number of truthy elements in x.
count_true  = function(x) length(which(x))

#' Clamp the values in x to between mn, mx
clamp = function(x, mn, mx) {
  x[ x < mn ] <- mn
  x[ x > mx ] <- mx
  x
}

#' Root-mean-square
rms = function(x) sqrt(mean(x*x))

#' Stop execution if x is not truthy.
assert = function(x, msg=function(x) paste("assertion error:", x)) {
  if (!x) {
    stop(msg(x))
  }
}

#' Stop execution if x is not empty.
assert_none = function(x, msg=function(x) write.table(x, sep="\t", row.names=FALSE)) {
  assert(nrow(x) == 0, msg)
}

#' Interpolate n points between start and stop.
linspace = compiler::cmpfun(function(start, stop, n) {
  n2 = n - 1
  d = stop - start
  start + (0:n2)*(d/n2)
})

#' Create a plot from formula
plotf = function(df, f, geom=geom_point) {
  p <- NULL
  if (length(f) == 2) {
    # histogram
    p <- ggplot(df, aes(x=!!f[[2]])) + geom_histogram()

  } else if (length(f) == 3) {
    # scatter plot
    y = f[[2]]
    x = f[[3]]

    if (length(y) != 1) stop("bad formula")

    if (length(x) == 1) {
      p <- ggplot(df, aes(x=!!x, y=!!y)) + geom()
    }

    if (length(x) == 3) {
      # scatter with colour
      colour = x[[3]]
      x = x[[2]]

      if (length(x) == 1) {
        p <- ggplot(df, aes(y=!!y, x=!!x, colour=!!colour)) + geom()
      }

      if (length(x) == 3) {
        # scatter with colour and wrap
        wrap = colour
        colour = x[[3]]
        x = x[[2]]

        if (length(x) == 1) {
          p <-
            ggplot(df, aes(y=!!y, x=!!x, colour=!!colour)) +
            geom() +
            facet_wrap(vars(!!wrap))
        }

        if (length(x) == 3) {
          # scatter with colour and grid
          grid = wrap
          wrap = colour
          colour = x[[3]]
          x = x[[2]]

          if (length(x) == 1) {
            p <-
              ggplot(df, aes(y=!!y, x=!!x, colour=!!colour)) +
              geom() +
              facet_grid(
                rows = vars(!!grid),
                cols = vars(!!wrap)
              )

          } else {
            stop("bad formula")
          }

        }

      }

    }

  } else {
    # error
    stop("bad formula")
  }

  return(p)
}

# replace all of the NAs with 0
replace_na_all = compiler::cmpfun(function(x) {
  x[is.na(x)] <- 0
  x
})

#' redo-ifchange the targets
redo = function(argv, ..., cmd=NULL) {

  argv = c(argv, ...)

  realcmd =
    if (is.null(cmd)) {
      "redo-ifchange"
    } else if (cmd %in% c("", "redo")) {
      "redo"
    } else {
      paste0("redo-", cmd)
    }

  msg = function(x) {
    logerror(
      "command line:\n\n    %s %s\n\nfailed with code %i",
      realcmd,
      paste(shQuote(argv), collapse = " "),
      x
    )
  }

  ec =
    system2(
      realcmd, argv,
      stdout = "", stderr = "",
      wait = TRUE, timeout = 0
    )

  assert(ec == 0, msg)

}

#' `redo-ifchange` the targets and load them in from RDS.
#' Loads the targets into the specified env, by default, the global one.
#' Passing `.env=NULL` will instead load the items into a `list()` and return that.
redo_load = function(..., .env=.GlobalEnv) {
  argv = c(...)

  redo(argv)

  dest =
    if (is.null(.env)) {
      list()
    } else {
      .env
    }

  for (k in names(argv)) {
    dest[[k]] = readRDS(argv[[k]])
  }

  invisible(dest)
}

#' like `redo`, but put args through `here` first
redo_here = function(..., cmd=NULL) {
  redo(here(c(...)), cmd = cmd)
}

#' Reload this file; useful for interactive sessions.
reload_utils = function() {
  source(here("utils.R"))
}
