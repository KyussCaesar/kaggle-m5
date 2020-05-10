
source(here::here("rpkgs.R"))
suppressPackageStartupMessages({
  for (p in rpkgs) {
    packageStartupMessage("\n==== LOAD PKG ", p, "\n")

    # some pkgs load _SO MUCH STUFF_
    # others, I really only want a couple things at most.
    # skip loading if they are in this list
    # can always refer to objects by pkg::object
    dontload = c(
      "R.utils",
      "plotly",
      "logging",
      "qs",
      "pryr",
      "flexdashboard",
      "zoo",
      "igraph",
      "Ckmeans.1d.dp"
    )

    if (p %in% dontload) {
      packageStartupMessage("SKIPPED")
    } else {
      library(p, character.only = TRUE)
    }
  }
})

logging::basicConfig()
loginfo  <- logging::loginfo
logwarn  <- logging::logwarn
logerror <- logging::logerror

ggplotly <- plotly::ggplotly

ncores = parallel::detectCores()

qsave <- function(x, fp) {
  #loginfo("save qs to %s", fp)
  qs::qsave(x, fp, preset = "high", nthreads = ncores)
}

qload <- function(fp) {
  #loginfo("load qs from %s", fp)
  qs::qread(fp, strict = TRUE, nthreads = ncores)
}

len <- length

rollapply  <- zoo::rollapply
rollmaxr   <- zoo::rollmaxr
rollmax    <- zoo::rollmax
rollsum    <- zoo::rollsum
rollapplyr <- zoo::rollapplyr
rollsumr   <- zoo::rollsumr
rollmean   <- zoo::rollmean
rollmedianr<- zoo::rollmedianr
rollmeanr  <- zoo::rollmeanr
rollmedian <- zoo::rollmedian

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
#' Pass NULL to ignore bound
clamp = compiler::cmpfun(function(x, mn, mx) {

  if (!is.null(mn)) x[ x < mn ] <- mn
  if (!is.null(mx)) x[ x > mx ] <- mx

  x
})

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

    if (
      "GeomBoxplot" %in% class(geom$geom) ||
      "GeomViolin" %in% class(geom$geom)
    ) {
      msg("convert boxplot col: ", nn)
      df[[nn]] <<- sprintf("%02i", df[[nn]])
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
    dest[[k]] = qload(argv[[k]])
  }

  invisible(dest)
}

#' Shortcut for the general case of `redo_load(foo = here("data/foo.qs"))`
reload = function(..., .env=.GlobalEnv) {
  argv = c(...)
  argv2 = list()

  for (a in argv) {
    argv2[[a]] = here(sprintf("data/%s.qs", a))
  }

  argv2[[".env"]] = .env

  invisible(do.call(redo_load, argv2))
}

mk_redo_load_db = function(conn) {
  function(..., .env=.GlobalEnv) {
    rl = redo_load(..., .env=NULL)

    dest =
      if (is.null(.env)) {
        list()
      } else {
        .env
      }

    for (k in names(rl)) {
      # copy the table into the DB, along with any indices

      d = rl[[k]]

      dest[[k]] =
        copy_to(
          conn, d, name = k,
          overwrite = TRUE,
          indexes =
            lapply(c(key(d), indices(d)), function(x) {
              strsplit(x, "__", fixed = TRUE)[[1]]
            })
        )
    }

    # rm rl and gc
    # after all, the idea is this is to reduce memory usage...
    rm(rl)
    gc(full = TRUE)

    invisible(dest)
  }
}

#' like `redo`, but put args through `here` first
redo_here = function(..., cmd=NULL) {
  redo(here(c(...)), cmd = cmd)
}

#' redo-stamp the file
redo_stamp = function(ff) {
  redo(cmd="stamp", stdin=ff)
}

#' Reload this file; useful for interactive sessions.
reload_utils = function() {
  source(here("utils.R"))
}

#' Take `df` and transform it into the submission format
make_submission = function(df) {
  redo_load(
    items = here("data/items.qs"),
    stores = here("data/stores.qs")
  )

  stopifnot(all(
   c("target_d", "item_id", "store_id", "pred") %in% colnames(df)
  ))

  min_dates =
    data.table(
      submission_type = c("validation", "evaluation"),
      min_date = as.integer(c(1914 - 1, 1942 - 1))
    )

  submission =
    list(
      submission_type = c("validation", "evaluation"),
      horizon = 1:28
    ) %>%
    cross_df() %>%
    as.data.table() %>%
    lazy_dt(immutable = FALSE) %>%
    left_join(min_dates, by = "submission_type") %>%
    transmute(
      target_d = min_date + horizon,
      horizon,
      submission_type
    ) %>%
    left_join(
      df[target_d > (1914 - 1), c("target_d", "item_id", "store_id", "pred")],
      by = "target_d"
    ) %>%
    left_join(
      items[,c("item_id", "item_name")],
      by = "item_id"
    ) %>%
    left_join(
      stores[,c("store_id", "store_name")],
      by = "store_id"
    ) %>%
    transmute(
      id = paste(item_name, store_name, submission_type, sep = "_"),
      horizon,
      pred
    ) %>%
    as_tibble() %>%
    pivot_wider(
      names_from = "horizon",
      values_from = "pred",
      names_prefix = "F"
    )

  submission
}

#' Create a new progress bar.
mkbar = function(msg, total) {
  pb <-
    progress_bar$new(
      total = total,
      clear = FALSE,
      format = sprintf("%s [:bar] :current/:total (:percent) :elapsed elapsed (:eta remain, :tick_rate/s)", msg),
      width = 110,
      show_after = 0
    )
  pb
}

#' Return a new x without names.
unnamed = function(x) {
  names(x) <- NULL
  x
}

#' Apply mapf then reduce using redf.
#' Different to xs %>% map(f) %>% reduce(g) is that we apply the map
#' one-at-a-time, i.e "map -> reduce -> map -> reduce" rather than
#' "map -> map -> reduce -> reduce"
mapreduce = compiler::cmpfun(function(xs, mapf, redf, progmsg=NULL) {

  pb = NULL
  if (!is.null(progmsg)) pb = mkbar(progmsg, len(xs))
  tick = ifelse(is.null(pb), function() {}, function() pb$tick())

  stopifnot(len(xs) != 0)

  state = mapf(xs[[1]])
  tick()

  if (len(xs) > 1) {
    for (i in 2:len(xs)) {
      state = redf(state, mapf(xs[[i]]))
      gc(full = TRUE)
      tick()
    }
  }

  state
})

object_size_str = function(x) {
  capture.output({
    print(pryr::object_size(x))
  })
}
