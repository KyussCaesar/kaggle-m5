# xgboost
setwd(here("xgboost"))

create_dm_skeleton = function() {
  reload("sales", .env = environment())
  dm_chunk = unique(sales[, .(target_id, item_id, store_id, state_id, cat_id, dept_id)])

  targets_to_mk = 1:1969
  pb = mkbar("prepare dm skeleton", len(targets_to_mk))

  for(target_d in 1:1969) {
    dm_chunk_d = merge(dm_chunk, sales[d == target_d], by = c("target_id", "item_id", "store_id", "state_id", "cat_id", "dept_id"), all.x = TRUE)

    dm_chunk_d$d = NULL
    dm_chunk_d$price = NULL
    dm_chunk_d$trnovr = NULL

    dest = here("xgboost", glue("features/_skeleton/{target_d}/1"))
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    qsave(dm_chunk_d, dest)
    pb$tick()
  }

  rm(sales)
  gc(full = TRUE)

  cat(strftime(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), file = here("xgboost/features/_skeleton/build-end"))

  NULL

}

create_dm = function(features, ds) {
  # make sure the "features" _starts_ with the skeleton
  if ("_skeleton" %in% features) features <- features[features != "_skeleton"]

  loginfo("Creating DM with the following features:")
  cat("", features, sep = "\n\t")
  cat("\n")

  load_d = function(feature_name, d) {
    load_dir = here("xgboost", glue("features/{feature_name}"))
    if (!file.exists(glue("{load_dir}/build-end"))) {
      stop(feature_name, " has not finished building")
    }

    load_from = glue("{load_dir}/{d}")
    load_files = list.files(load_from, full.names = TRUE)

    if (len(load_files) == 0) {
      # feature does not exist for that day
      # assume we are building features for the validation/evaluation set
      # so just return empty df
      # using d = 1 as a template
      warning(feature_name, " has not been built for d = ", d, ": will use empty frame instead")
      df = load_d(feature_name, 1)[1,]
      df[,] <- NA

    } else {
      df = mapreduce(load_files, qload, rbind)

    }

    df
  }

  # prepare the dm skeleton
  # do this ahead of time so each date only gets loaded once
  dm_target_dates =
    ds %>%
    sapply(function(x) x + 1:28) %>%
    c() %>%
    unique() %>%
    sort()

  dm_skeleton =
    mapreduce(dm_target_dates, function(target_d) {
      df = load_d("_skeleton", target_d)
      df$target_d = target_d

      df
    },
      rbind
    )

  features = c("_skeleton", features)

  left_merge = function(x, y) {
    bycols = intersect(colnames(x), colnames(y))

    # merge is only done within a particular date
    # this means `d` is not necessary
    # target_d and j are aliases, so only need one of them
    # bycols = bycols[!(bycols %in% c("d", "j"))]
    setkeyv(x, bycols)
    setkeyv(y, bycols)

    #loginfo("merging by (%s)", paste0(bycols, collapse = ", "))
    merge(x, y, by = bycols, all.x = TRUE, allow.cartesian = TRUE)
  }

  load_feature = function(feature_name, d) {
    if (feature_name == "_skeleton") {
      df = dm_skeleton[target_d %in% c(d + 1:28)]
      df$d = d
      df$j = df$target_d - df$d
      df

    } else if (feature_name == "dates") {
      reload("dates", .env = environment())
      df = dates[,.(target_d = d, year, mnth, wday, nth_wday_in_mnth, year_pos, mnth_pos)]

    } else if (feature_name == "launch_dates") {
      reload("launch_dates", .env = environment())
      df = launch_dates

    } else if (feature_name == "days_since_launch") {
      reload("launch_dates", .env = environment())
      df =
        launch_dates %>%
        as_tibble() %>%
        mutate(d = {{ d }}) %>%
        crossing(j = 1:28) %>%
        mutate(
          target_d = d + j,
          days_since_launch = target_d - launch_date_i
        ) %>%
        select(target_id, target_d, days_since_launch) %>%
        as.data.table()

    } else {
      df = load_d(feature_name, d)

      df$d = d
      df$j = list(1:28)

      # unnest any list-cols
      lcols = sapply(df, is.list)
      colunnest = colnames(df)[lcols] %>% map(function(x) glue("{x} = unlist({x})")) %>% paste0(collapse = ", ")
      colby = colnames(df)[!lcols] %>% paste0(collapse = ", ")
      df = parse(text = glue("df[, .({colunnest}), keyby = .({colby})]")) %>% eval()

      df$target_d = df$d + df$j
    }

    df
  }

  df =
    mapreduce(ds, function(d)
      mapreduce(features, function(feature_name)
        load_feature(feature_name, d),
        left_merge
      ),
      rbind
    )

  loginfo("Design matrix loaded: (%i rows, %i cols, %s)", nrow(df), ncol(df), object_size_str(df))
  gc(full = TRUE)

  df
}

run_name = "long-train"
rundir = here("xgboost", "runs", run_name)
if (!dir.exists(rundir)) {
  dir.create(rundir, recursive = TRUE)
}

setwd(rundir)

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
# choose a number of days at random from the past, bias towards later values
set.seed(2357894)
N = c(sample(1:1855, 28, prob = 1:1855), 1884, 1913, 1941)
debugit(len(N))

# when validation set is made available, use this one
#N = c((1884 - 3):1884, 1913, 1941)

dm_features =
  c(
    "dates",
    "days_since_launch",
    "tgt_volume_sum_snaive_1",
    "str_volume_sum_smom_2",
    "tgt_volume_sum_rollmeanr_84"
  )

dm = create_dm(dm_features, N)

# TODO: generate more features:
# - scaling terms for RMSSE

# TODO: figure out a way around memory limits
# - atm running up against max memory available to the machine :\
# - this means I can only use about a week's worth of training data :'(
# - idea: try building the DM in SQLite, then only pull it out at the end
#   sales takes 2GB; atm the whole DM is only 1GB, but memory usage of the container
#   hits 10GB :'(
# - idea: create the DM in chunks
#   could be a case where using the whole thing at once uses more memory than smaller chunks

# loginfo("save the DM")
qsave(dm, "dm.qs")
# dm = qload("dm.qs")

loginfo("train/test split")

set.seed(5784)

# choose test date
#test_date = sample(dm[,n], 1)
test_date = 1884

# split into train/test
d_trn = dm[d + max(J) <  test_date]
d_tst = dm[d          == test_date]

trn_x = as.matrix(d_trn[,-"volume", with = FALSE])
trn_y = as.matrix(d_trn[, "volume"])
trn_base = as.matrix(rep(0, nrow(d_trn)))

tst_x = as.matrix(d_tst[,-"volume", with = FALSE])
tst_y = as.matrix(d_tst[, "volume"])
tst_base = as.matrix(rep(0, nrow(d_tst)))

# qsave(trn_x, "trn_x.xgb")
# qsave(trn_y, "trn_y.xgb")
# qsave(trn_base, "trn_base.xgb")
#
# qsave(tst_x, "tst_x.xgb")
# qsave(tst_y, "tst_y.xgb")
# qsave(tst_base, "tst_base.xgb")
#
# trn_x = qload("trn_x.xgb")
# trn_y = qload("trn_y.xgb")
# trn_base = qload("trn_base.xgb")
#
# tst_x = qload("tst_x.xgb")
# tst_y = qload("tst_y.xgb")
# tst_base = qload("tst_base.xgb")

loginfo("trn set prepared (%i rows, %i cols, %s)", nrow(trn_x), ncol(trn_x), object_size_str(trn_x))
loginfo("tst set prepared (%i rows, %i cols, %s)", nrow(tst_x), ncol(tst_x), object_size_str(tst_x))

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
  #nthread = parallel::detectCores(),
  nthread = 6,
  eta = 0.05,
  gamma = 0.025,
  max_depth = 3,
  min_child_weight = 0.1,
  max_delta_step = 0,
  subsample = 1,
  sampling_method = "uniform",
  colsample_bytree = 1,
  colsample_bylevel = 1,
  colsample_bynode = 1,
  lambda = 0,
  alpha = 0,
  tree_method = "hist",
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

d_vald = dm[d == 1913]
vald_x = as.matrix(d_vald[,-"volume", with = FALSE])
vald_y = as.matrix(d_vald[, "volume"])

d_vald$pred = clamp(predict(mdl, xgb.DMatrix(vald_x, label = vald_y), ntreelimit = best_iter), 0, NULL)

# PREDICTION FOR EVALUATION SET
loginfo("Generate predictions for evaluation set")

d_eval = dm[d == 1941]
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

cat("rmse at best_iter:\n")
print(mdl$evaluation_log[iter == best_iter,])
cat("\n")

cat("features:\n")
for (n in dm_features) {
  cat(" ", n, "\n")
}
cat("\n")

cat("params:\n")
for (n in names(params)) {
  cat(" ", n, "=", params[[n]], "\n")
}
cat("\n")

cat("nrow d_trn:\n")
print(nrow(d_trn))
cat("\n")

sink()

gc(full = TRUE)

setwd(here("xgboost"))

