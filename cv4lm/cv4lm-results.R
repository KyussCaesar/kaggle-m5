# Analyses to carry out:
# - examine RMSE for a single model
# - examine RMSE of combinations of models
# - "CV" to find optimal combination of models
# - examine model parameters learned

argv = commandArgs(TRUE)

# debug values
# argv = c(
#   "cv4lm.db",
#   "INSERT INTO cvlm VALUES (:chunk_name, :cutoff, :target_id, :mdl_win, :mdl_coef, :mdl_coef_stderr, :mdl_coef_statistic, :mdl_coef_pvalue, :horizon, :volume, :mdl_pred, :mdl_err);",
#   "lmcv-0001.rds"
# )

chunk = argv[3]

# suppress all output
logfile = file(paste0(chunk, ".log"), open = "wt")
sink(logfile, type = "output")
sink(logfile, type = "message")

conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = argv[1])

# set the busy_timeout
# this is to allow this process to wait for another writer to finish writing
# before this one can start writing
pbt = DBI::dbSendStatement(conn, "PRAGMA busy_timeout = 100000000;")
DBI::dbClearResult(pbt)

prep_stmt = argv[2]

DBI::dbBegin(conn)
rs = DBI::dbSendStatement(conn, prep_stmt)

# Analysis 1: looking at the RMSE of a single model object, and how
# it changes per d, target_id, item_id, store_id, lm_win
cr =
  chunk %>%
  readRDS() %>%
  transmute(
    cutoff,
    target_id,
    # note: compiling this function actually make things _slower_
    res = pmap(list(res, tst), function(res, tst) {
      res2 =
        res %>%
        unnest(cols = c("res")) %>%
        transmute(
          mdl_win  = as.integer(value),
          mdl_pred = lapply(mdl, function(m) clamp(predict(m, tst), 0, NULL)),
          volume   = list(tst[,volume])
        ) %>%
        unnest(cols = c(
          mdl_pred,
          volume
        )) %>%
        transmute(
          mdl_win,
          horizon = as.integer(1:n()),
          volume,
          mdl_pred
        )

      res2
    })
  ) %>%
  unnest(cols = res) %>%
  pmap(function(...) {
    DBI::dbBind(rs, list(...))
  })

invisible(DBI::dbClearResult(rs))
DBI::dbCommit(conn)
DBI::dbDisconnect(conn)

# warnings can cause a non-zero exit status
quit(save = "no", status = 0)

# system.time({
#   cr =
#     readRDS("lmcv-0001.rds") %>%
#     #head(3) %>%
#     transmute(
#       k,
#       cutoff,
#       target_id,
#       trn,
#       tst,
#       res = pmap(list(res), function(x) x %>% unnest(cols = c("res")) %>% select(lm_win = value, mdl))
#     ) %>%
#     unnest(cols = res) %>%
#     mutate(
#       preds = pmap(list(tst, mdl), function(tst, mdl) {
#         pred_raw = predict(mdl, tst)
#         pred = clamp(round(pred_raw), 0, NULL)
#         err = tst[,volume] - pred
#
#         # calculate metrics
#         tibble(
#           rmse = rms(err),
#           mae = mean(abs(err)),
#           mse = mean(err * err),
#           pred_raw = list(pred_raw),
#           pred = list(pred),
#           err = list(err),
#           tidy = list(tidy(mdl)),
#           glance = list(glance(mdl))
#         )
#       })
#     ) %>%
#     unnest(cols = preds)
# })
