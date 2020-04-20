# xgboost

run_name = "dateinfo"
rundir = here("xgboost", "runs", run_name)
if (!dir.exists(rundir)) {
  dir.create(rundir, recursive = TRUE)
}

setwd(rundir)

reload("sales")

# indexes; these are the target IDs, i.e the thing we're actually forecasting
I = unique(sales[,target_id])

# horizons
J = 1:28

# heirarchy levels
L = 1:12

# cutoff dates; i.e last dates in training sets
# first chunk is all the training dates
# next is the validation set
# finally, the evaulation set
# we don't use _all_ the training data cause it's too big for my computer :(
# for now just testing...
N = c((1855 - 8):1855, 1884, 1913, 1941)
debugit(len(N))

# when validation set is made available, use this one
#N = c((1884 - 3):1884, 1913, 1941)

dm_nrow = len(I) * len(N) * len(J)
loginfo("Generate DM skeleton with %i rows", dm_nrow)

dm =
  list(
    i = I,
    n = N,
    j = J
  ) %>%
  cross_df() %>%
  as.data.table()

setkey(dm, "i")
setindex(dm, "n")
setindex(dm, "j")
setindex(dm, "i", "n")

# note: need to add filter; drop rows where n < launch_date(i)
# this is because the error is scaled against the 1-step naive forecast error on the training data
# which is undefined if there is no history for series i.
reload("launch_dates")
dm = merge(dm, launch_dates, by.x = "i", by.y = "target_id", all.x = TRUE)[n > launch_date_i + 1]

# add identifiers
dm =
  merge(
    dm, unique(sales[,.(id = target_id, item_id, store_id, cat_id, dept_id, state_id)]),
    by.x = "i", by.y = "id", all.x = TRUE
  )

# define target_d
dm$target_d = dm$n + dm$j

# add the target
dm = merge(dm, sales[,c("target_id", "d", "volume")], by.x = c("i", "target_d"), by.y = c("target_id", "d"), all.x = TRUE)

# feature: days_since_launch
dm$days_since_launch = dm$n + dm$j - dm$launch_date_i

# feature: last known sales
dm = merge(dm, sales[, .(target_id, d, volume_1 = volume)], by.x = c("i", "n"), by.y = c("target_id", "d"), all.x = TRUE)

# feature: date info
redo_load(dates = here("data/dates.rds"))
dm = merge(
  dm, dates[,.(d, year, mnth, wday, nth_wday_in_mnth, year_pos, mnth_pos)],
  by.x = "target_d", by.y = "d", all.x = TRUE
)

# feature: ARIMA forecasts
pb_arima <- NULL

arima_backwindow = max(J) + 7

arima_forecasts =
  sales %>%
  lazy_dt() %>%
  filter(d >= min(N) - arima_backwindow) %>%
  select(target_id, d, volume) %>%
  as_tibble() %>%
  (function(x) {
    pb_arima <<- mkbar("create ARIMA forecasts", nrow(x))
    x
  }) %>%
  nest(data = c(d, volume)) %>%
  mutate(data = map(data, compiler::cmpfun(function(x) {
    x2 =
      x %>%
      arrange(d) %>%
      as.data.table()

    these_ds = x2[,d]
    res = vector(mode = "list", length = len(these_ds))

    for (dx in seq_along(these_ds)) {
      di = these_ds[dx]
      trn = x2[d <= di & d > di - arima_backwindow,]

      if (nrow(trn) > 5) {
        mdl =
          auto.arima(
            trn[,volume],
            lambda = "auto",
            biasadj = TRUE
          )

        fcs = forecast(mdl, h = max(J), level = 85)
        arima_forecast = clamp(as.double(fcs[["mean"]]), 0, NULL)
        arima_forecast[is.nan(arima_forecast)] <- 0 # remove NaNs created by back-transform (biasadj)
        arima_ci85_lo = clamp(as.double(fcs$lower), 0, NULL)
        arima_ci85_hi = clamp(as.double(fcs$upper), 0, NULL)

      } else {
        # use naiive forecast
        arima_forecast = trn[d == di, volume]
        arima_ci85_lo = NA
        arima_ci85_hi = NA
      }

      res[[dx]] =
        tibble(
          n = di,
          target_d = di + J,
          arima_forecast = arima_forecast,
          arima_ci85_lo = arima_ci85_lo,
          arima_ci85_hi = arima_ci85_hi
        )

      pb_arima$tick()
    }

    do.call(rbind, res)
  }))) %>%
  unnest(cols = "data")

# TODO: generate more features:
# - rolling mean for last 7, 14, 28 days (revenue/sales volume)
# - predictions from ARIMA (revenue/sales volume)
# - scaling terms for RMSSE

# TODO: figure out a way around memory limits
# - atm running up against max memory available to the machine :\
# - this means I can only use about a week's worth of training data :'(
# - idea: try building the DM in SQLite, then only pull it out at the end
#   sales takes 2GB; atm the whole DM is only 1GB, but memory usage of the container
#   hits 10GB :'(
# - idea: create the DM in chunks
#   could be a case where using the whole thing at once uses more memory than smaller chunks

loginfo("train/test split")

set.seed(5784)

# choose test date
#test_date = sample(dm[,n], 1)
test_date = 1884

# split into train/test
d_trn = dm[n + max(J) <  test_date]
d_tst = dm[n          == test_date]

trn_x = as.matrix(d_trn[,-"volume", with = FALSE])
trn_y = as.matrix(d_trn[, "volume"])
trn_base = as.matrix(rep(0, nrow(d_trn)))

tst_x = as.matrix(d_tst[,-"volume", with = FALSE])
tst_y = as.matrix(d_tst[, "volume"])
tst_base = as.matrix(rep(0, nrow(d_tst)))

trn =
  xgb.DMatrix(
    trn_x,
    info = list(
      label = trn_y,
      base_margin = trn_base
    )
  )

tst =
  xgb.DMatrix(
    tst_x,
    info = list(
      label = tst_y,
      base_margin = tst_base
    )
  )

loginfo("Begin the training")

params = list(
  nthread = parallel::detectCores(),
  eta = 0.03,
  gamma = 1,
  max_depth = 6,
  min_child_weight = 5,
  max_delta_step = 0,
  subsample = 1,
  sampling_method = "uniform",
  colsample_bytree = 1,
  colsample_bylevel = 1,
  colsample_bynode = 1,
  lambda = 0,
  alpha = 0,
  tree_method = "exact",
  num_parallel_tree = 1
)

mdl =
  xgb.train(
    trn,
    params = params,
    nrounds = 100,
    watchlist = list(
      trn = trn,
      tst = tst
    ),
    objective = "reg:squarederror",
    eval_metric = "rmse"
  )

# figure out the best iteration
best_iter = mdl$evaluation_log[which(tst_rmse == min(tst_rmse))][["iter"]]

loginfo("Generate predictions on training and testing sets")
d_trn$preds = clamp(predict(mdl, trn, ntreelimit = best_iter), 0, NULL)
d_tst$preds = clamp(predict(mdl, tst, ntreelimit = best_iter), 0, NULL)

# PREDICTION FOR VALIDATION SET
loginfo("Generate predictions for validation set")

d_vald = dm[n == 1913]
vald_x = as.matrix(d_vald[,-"volume", with = FALSE])
vald_y = as.matrix(d_vald[, "volume"])

d_vald$pred = clamp(predict(mdl, xgb.DMatrix(vald_x, label = vald_y), ntreelimit = best_iter), 0, NULL)

# PREDICTION FOR EVALUATION SET
loginfo("Generate predictions for evaluation set")

d_eval = dm[n == 1941]
eval_x = as.matrix(d_eval[,-"volume", with = FALSE])
eval_y = as.matrix(d_eval[, "volume"])

d_eval$pred = clamp(predict(mdl, xgb.DMatrix(eval_x, label = eval_y), ntreelimit = best_iter), 0, NULL)

# transform d_vald and d_eval into submission format
loginfo("Generate submission.")

submission = make_submission(rbind(d_vald, d_eval))

write_csv(submission, "submission.csv")
qsave(mdl, "mdl.qs")
qsave(d_trn, "d_trn.qs")
qsave(d_tst, "d_tst.qs")
qsave(d_vald, "d_vald.qs")
qsave(d_eval, "d_eval.qs")
qsave(submission, "submission.qs")

sink("run-description.txt")
cat("xgboost\n\n")
cat("nrow d_trn:\n")
print(nrow(d_trn))
cat("\n")

cat("params:\n")
for (n in names(params)) {
  cat(" ", n, "=", params[[n]], "\n")
}
cat("\n")

cat("rmse at best_iter:\n")
print(mdl$evaluation_log[iter == best_iter,])
cat("\n")

sink()

