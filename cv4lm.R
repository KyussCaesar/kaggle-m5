# CV to see how far back an lm should look.
# Will try combining the results to see if that improves score.

loginfo("Loading sales... ")
redo_load(sales = here("data/sales.rds"))

# try each of 1 lm, 2 lms, or 4 lms
# actually, we can figure this out from the results of using 1 lm by combining
# results for the same fold
# nlms = c(1, 2, 4)
nlms = c(1)
debugit(nlms)

# how far back to look when fitting the lm
# zero means disabled
nwin = c(3, 7, 14, 28)
max_nwin = max(nwin)
debugit(nwin)

# TODO: this is superflous
# we should just train each nwin once for each cutoff, but instead we train
# a number of times (each time that nwin appears in a spec)

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
  mutate(
    lmspec = lapply(lmspec, gather),
    lmi = 1L # dummy id to cross-join, later
  )

loginfo("Done preparing lmspecs.")
loginfo("Setting other variables")

#nfolds = 10
nfolds = 70
max_horizon = 28

set.seed(78563)
tt = unique(sales[["target_id"]])
# need to generate trn/tst for each target id
# there's _a lot_, 30K or so
# cut down to 1/5th of the dataset to keep it manageable
v_targets = tt
# v_targets = sample(tt, length(tt) / 5)

# process the skeleton in chunks
# this is actually a tunable parameter; but for code-speed, not model performance
# make it larger -> fewer chunks, but each chunk is processed more slowly
# make it smaller -> each chunk processed faster, but much more chunks to process
# in my testing it was cutting down the sales for a particular target and test date
# that was slow; so we cut down the sales _once_, ahead of time, and then pull what
# we need from there.
#skiplen = 5000
#skiplen = 25000
skiplen = 500

dbgmode = FALSE
if (dbgmode) {
  set.seed(257)
  lmspecs = sample_n(lmspecs, 2)
  v_targets = sample(tt, 1)
  nfolds = 2
  skiplen = 3
}

debugit(nfolds)
debugit(skiplen)

set.seed(57894)
dd = unique(sales[["d"]])
v_cutoff = sample(dd, nfolds, prob = dd)
debugit(v_cutoff)

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

# cut down the sales to just what we need
# this speeds up everything _a lot_
loginfo("Cut down sales (global)")
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

lmcv_skel =
  tibble(k = 1:nfolds) %>%
  mutate(
    cutoff = v_cutoff
  ) %>%
  crossing(
    target_id = v_targets
  )

ci = seq(1, nrow(lmcv_skel), skiplen)
cn = length(ci)
cc = 0

fnfmt = paste0("lmcv-%0", floor(log10(cn)) + 1, "i.rds")

for (i in ci) {
  if ((cc %% 12) == 0) {
    loginfo("Running GC")
    gc(full = TRUE)
  }

  cc <- cc + 1
  loginfo("Begin processing chunk %i/%i", cc, cn)

  c_beg = proc.time()[3]

  lmcv_this = lmcv_skel[seq(i, min(i + skiplen - 1, nrow(lmcv_skel))),]

  # cut down sales _again_ to just what we need for this chunk
  loginfo("Cut down sales (chunk)")
  sales_cut =
    sales[
      d <= (max(lmcv_this$cutoff) + max_horizon) &
      d >= (min(lmcv_this$cutoff) - max(nwin)) &
      target_id %in% lmcv_this$target_id,
      c("target_id", "volume", "d")
    ]

  setkey(sales_cut, "target_id", "d")
  setindex(sales_cut, "target_id")
  setindex(sales_cut, "d")

  pb_tt <- mkbar("create tt", nrow(lmcv_this))
  pb_cv <- mkbar("create lm", nrow(lmcv_this) * nrow(lmspecs))

  lmcv_chunk =
    lmcv_this %>%
    mutate(
      trntst = pmap(list(cutoff, target_id), compiler::cmpfun(function(cutoff, tid) {
        s =
          sales_cut[
            target_id == tid &
            d >  (cutoff - max_nwin) &
            d <= (cutoff + max_horizon),
            c("volume", "d")
          ][order(d)]

        trn = head(s, -max_horizon)
        tst = tail(s,  max_horizon)

        pb_tt$tick()
        tibble(trn = list(trn), tst = list(tst))
      })),

      lmi = 1L # dummy id to cross join
    ) %>%
    unnest(cols = trntst) %>%
    left_join(lmspecs, by = c("lmi")) %>%
    mutate(
      res = pmap(list(lmspec, trn, tst), function(lmspec, trn, tst) {
        res =
          lmspec %>%
          mutate(res = lapply(value, function(x) {
            pb_cv$tick()

            if (x == 0) return(NULL)

            mdl = lm(volume ~ d, data = tail(trn, x))
            # pred_raw = predict(mdl, tst)
            # pred = clamp(round(tst[,pred_raw]), 0, NULL)

            tibble(mdl = list(mdl))
          }))

        res
      })
    )

  saveRDS(lmcv_chunk,  sprintf(fnfmt, cc))

  c_end = proc.time()[3]
  c_dur = c_end - c_beg
  loginfo("Done processing chunk %i, took %f seconds", cc, c_dur)
}

loginfo("Done processing all chunks")
