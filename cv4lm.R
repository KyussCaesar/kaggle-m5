# CV to find:
# - how many lms to fit
# - for each one, how far back should the window look?
#
# afterwards:
# - see if breaking out by horizon is useful or not
#
# end goal:
# - spec: how many lms to fit, and for each one how far back it should look, possibly different by horizon or group of horizons
#

loginfo("Loading sales... ")
redo_load(sales = here("data/sales.rds"))

# try each of 1 lm, 2 lms, or 4 lms
nlms = c(1, 2, 4)

# how far back to look when fitting the lm
# zero means disabled
nwin = c(0, 3, 7, 14, 28)

loginfo("Generate lmspecs...")
lmspecs =
  seq(min(nlms), max(nlms)) %>%
  lapply(function(x) {
    r = list()
    n = paste0("lm_", x)
    r[[n]] = nwin

    as.data.frame(r)
  }) %>%
  bind_cols() %>%
  cross_df(.filter = function(...) {
    x <- c(...)

    # number of lms
    # drop cases not in nlms
    nlm = length(x) - sum(x == 0)
    if (!(nlm %in% nlms)) return(TRUE)

    # drop cases that are double-ups
    # filter for this by asserting the spec must contain
    # lm windows that are strictly decreasing
    if (length(x) > 1) {
      for (i in seq(2, length(x))) {
        if (x[[i]] != 0) {
          if (x[[i]] >= x[[i - 1]]) return(TRUE)
        }
      }
    }

    return(FALSE)
  }) %>%
  mutate(rowid = 1:n()) %>%
  nest(lmspec = starts_with("lm_")) %>%
  mutate(lmspec = lapply(lmspec, gather))

loginfo("Done preparing lmspecs.")
loginfo("Setting other variables")

nfolds = 10
max_horizon = 28

set.seed(78563)
tt = unique(sales[["target_id"]])
# need to generate trn/tst for each target id
# there's _a lot_, 30K or so
# cut down to 1/5th of the dataset to keep it manageable
# v_targets = tt
v_targets = sample(tt, length(tt) / 10)

mkbar = function(msg, total) {
  pb <-
    progress_bar$new(
      total = total,
      clear = FALSE,
      format = sprintf("%s [:bar] :current/:total (:percent) :elapsed elapsed (:eta remain, :tick_rate/s)", msg),
      width = 90,
      show_after = 0
    )
  pb
}

pb_cv = NULL
pb_mk_trn = NULL
pb_mk_tst = NULL

dbgmode = FALSE
if (dbgmode) {
  set.seed(257)
  lmspecs = sample_n(lmspecs, 2)
  v_targets = sample(tt, 1)
  nfolds = 2
}

set.seed(57894)
dd = unique(sales[["d"]])
v_cutoff = sample(dd, nfolds, prob = dd)
debugit(v_cutoff)

# cut down the sale to just what we need
# this speeds up everything _a lot_
# we also pre-generate the training and testing sets, which also speeds things up
loginfo("cut down sales")
sales =
  sales[
    d <= (max(v_cutoff) + max_horizon) &
    d >= (min(v_cutoff) - max(nwin)) &
    target_id %in% v_targets,
    c("target_id", "volume", "d")
  ]

setkey(sales, "target_id", "d")
setindex(sales, "target_id")
setindex(sales, "d")

loginfo("BEGIN CV")
lmcv =
  tibble(k = 1:nfolds) %>%
  mutate(
    cutoff = v_cutoff
  ) %>%
  crossing(
    lmi = lmspecs[["rowid"]],
    target_id = v_targets
  ) %>%
  (function(x) {
    pb_mk_trn <<- mkbar("create trn", nrow(x))
    pb_mk_tst <<- mkbar("create tst", nrow(x))
    pb_cv <<- mkbar("cv lm", nrow(x) * nrow(lmspecs) * max(nlms))

    loginfo("begin creating trn/tst sets")
    x
  }) %>%
  mutate(
    trn = pmap(list(cutoff, target_id), function(cutoff, tid) {
      trn =
        sales[
          d > cutoff - max(nwin) & d <= cutoff & target_id == tid,
          c("volume", "d")
        ][order(d)]
      pb_mk_trn$tick()
      trn
    }),

    tst = pmap(list(cutoff, target_id), function(cutoff, tid) {
      tst =
        sales[
          d > cutoff & d <= cutoff + max_horizon & target_id == tid,
          c("volume", "d")
        ]
      pb_mk_tst$tick()
      tst
    })
  ) %>%
  left_join(lmspecs, by = c("lmi" = "rowid")) %>%
  mutate(
    res = pmap(list(lmspec, trn, tst), function(lmspec, trn, tst) {
      res =
        lmspec %>%
        mutate(res = lapply(value, function(x) {
          pb_cv$tick()

          if (x == 0) return(NULL)

          mdl = lm(volume ~ d, data = tail(trn, x))
          tst[,"pred_raw"] = predict(mdl, tst)
          tst[,"pred"] = clamp(round(tst[,pred_raw]), 0, NULL)

          tibble(tst = list(tst), mdl = list(mdl))
        }))

      res
    })
  )

save.image("cv4lm.Rdata")

