
suppressPackageStartupMessages({
  library(plotly)
  # need to load stats before tidyverse so it doesn't shadow dplyr
  library(stats)
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
plotf = function(df, f, geom=geom_point, verbose=FALSE) {

  msg =
    if (verbose) {
      function(...) {
        message("plotf: ", ...)
      }
    } else {
      function(...) {}
    }

  # instantiate geom
  if (is.function(geom)) {
    msg("instantiate geom")
    geom = geom()
  }

  # resolve column name
  resolve_colname = function(nn, env = environment(), depth = 0) {
    nn = as.character(nn)

    msg("resolve colname: ", nn, " depth: ", depth)

    if (is.null(nn)) {
      stop("could not resolve ", nn)
    }

    if (depth > 32) {
      stop("recursion error while trying to resolve ", nn)
    }

    if (nn %in% names(df)) {
      msg("resolve colname: found: ", nn)
      return(nn)
    }

    next_try =
      if (nn %in% names(env)) {
        env[[nn]]
      } else {
        nn
      }

    msg("resolve colname: next_try: ", next_try)
    return(resolve_colname(next_try, env = parent.env(env), depth = depth + 1))
  }

  # processing for colour col
  # if low cardinality, coerce to character
  # otherwise leave it
  colour_col = function(nn) {
    msg("check colour col: ", nn)

    n_colours = cardinality(df[[nn]])

    if (n_colours < 30) {
      msg("converting colour col: ", nn)
      df[[nn]] <<- as.character(df[[nn]])
    }
  }

  # processing for faceting cols
  # if not character replace col with `colname=col`
  # nice for ggplot, if you have faceting variables that are just numbers and you
  # forget which axis is which in the facet plot
  facet_col = function(nn) {
    msg("check facet col: ", nn)

    if (!is.character(df[[nn]])) {
      msg("convert facet col: ", nn)
      df[[nn]] <<- paste0(nn, "=", df[[nn]])
    }
  }

  # for boxplot, you want the x to be factor
  boxplot_col = function(nn) {
    msg("check boxplot col: ", nn)

    if ("GeomBoxplot" %in% class(geom$geom)) {
      msg("convert boxplot col: ", nn)
      df[[nn]] <<- as.character(df[[nn]])
    }
  }

  p <- NULL
  if (length(f) == 2) {
    x = resolve_colname(f[[2]])

    msg("histogram: ", x)

    p <- function() {
      ggplot(df, aes_(x=as.name(x))) +
      geom_histogram()
    }

  } else if (length(f) == 3) {
    # scatter plot
    y = f[[2]]
    x = f[[3]]

    if (length(y) != 1) stop("bad formula")

    if (length(x) == 1) {
      y = resolve_colname(y)
      x = resolve_colname(x)

      msg("scatter: x: ", x, " y: ", y)
      boxplot_col(x)

      p <- function() {
        ggplot(df, aes_(x=as.name(x), y=as.name(y))) + geom
      }
    }

    if (length(x) == 3) {
      # scatter with colour
      colour = x[[3]]
      x = x[[2]]

      if (length(x) == 1) {
        y = resolve_colname(y)
        x = resolve_colname(x)
        colour = resolve_colname(colour)

        msg("scatter with colour: x: ", x, " y: ", y, " colour: ", colour)
        boxplot_col(x)
        colour_col(colour)

        p <- function() {
          ggplot(df, aes_(y=as.name(y), x=as.name(x), colour=as.name(colour))) + geom
        }
      }

      if (length(x) == 3) {
        # scatter with colour and wrap
        wrap = colour
        colour = x[[3]]
        x = x[[2]]

        if (length(x) == 1) {
          y = resolve_colname(y)
          x = resolve_colname(x)
          colour = resolve_colname(colour)
          wrap = resolve_colname(wrap)

          boxplot_col(x)
          colour_col(colour)
          facet_col(wrap)

          p <- function() {
            ggplot(df, aes_(y=as.name(y), x=as.name(x), colour=as.name(colour))) +
            geom +
            facet_wrap(as.name(wrap))
          }
        }

        if (length(x) == 3) {
          # scatter with colour and grid
          grid = wrap
          wrap = colour
          colour = x[[3]]
          x = x[[2]]

          if (length(x) == 1) {
            y = resolve_colname(y)
            x = resolve_colname(x)
            colour = resolve_colname(colour)
            wrap = resolve_colname(wrap)
            grid = resolve_colname(grid)

            boxplot_col(x)
            colour_col(colour)
            facet_col(wrap)
            facet_col(grid)

            p <- function() {
              ggplot(df, aes_(y=as.name(y), x=as.name(x), colour=as.name(colour))) +
              geom +
              facet_grid(
                rows = as.name(grid),
                cols = as.name(wrap)
              )
            }

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

  msg("generating plot...")
  return(p())
}

# replace all of the NAs with 0
replace_na_all = compiler::cmpfun(function(x) {
  x[is.na(x)] <- 0
  x
})

#' redo-ifchange the targets
redo = function(..., cmd=NULL, stdin="", verbose = FALSE) {

  argv = c(...)

  realcmd =
    if (is.null(cmd)) {
      "redo-ifchange"
    } else if (cmd %in% c("", "redo")) {
      "redo"
    } else {
      paste0("redo-", cmd)
    }

  cmdline = paste(realcmd, paste(shQuote(argv), collapse = " "))
  if (stdin != "") {
    cmdline = paste0(cmdline, " <", shQuote(stdin))
  }

  if (verbose) {
    message("redo: ", cmdline)
  }

  msg = function(x) {
    logerror(
      "command line:\n\n    %s\n\nfailed with code %i",
      cmdline,
      x
    )
  }

  ec =
    system2(
      realcmd, argv,
      stdout = "", stderr = "", stdin = stdin,
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

#' redo-stamp the file
redo_stamp = function(ff) {
  redo(cmd="stamp", stdin=ff)
}

#' Setup for RMD
rmdsetup = function() {
  scale = 2.5
  knitr::opts_chunk$set(
    echo = TRUE,
    # cache = TRUE,
    cache = FALSE,
    fig.align = "centre",
    fig.width = 4*scale,
    fig.height = 3*scale
  )
}

#' Reload this file; useful for interactive sessions.
reload_utils = function() {
  source(here("utils.R"))
}
