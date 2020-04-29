loginfo("Begin CV step.")
argv = commandArgs(TRUE)

expname = argv[1]
expdir = glue("experiments/{expname}")

# read config
config_src = glue("{expdir}/config.R")
config_env = new.env()
loginfo("Reading config.R from %s", config_src)
source(config_src, local = config_env, chdir = TRUE)

# read cvdb
cvdb_qs = glue("{expdir}/cv/cvdb.qs")
loginfo("Load cvdb from %s", cvdb_qs)
cvdb = qload(cvdb_qs)
print(cvdb)

incomplete =
  cvdb %>%
  filter(!done)

if (nrow(incomplete) == 0) {
  loginfo("All runs complete!")
  quit(status = 0, save = "no")
}

this_run  = as.list(incomplete[1,])
loginfo("Running this step:")
print(this_run)

round_id = this_run[["round_id"]]
run_id   = this_run[["run_id"]]

# get trn/tst dates for this round and run
base_seed = config_env[["base_seed"]]
n_dates   = config_env[["n_dates"]]

old_seed = .Random.seed
set.seed(base_seed + round_id)
set.seed(floor(runif(1, min = 0, max = .Machine$integer.max - 1048576)) + run_id)
dm_dates = sort(sample(1:1855, n_dates, prob = 1:1855))
dm_dates[len(dm_dates) + 1] = dm_dates[len(dm_dates)] + 28
.Random.seed = old_seed

trn_dates = dm_dates[-len(dm_dates)]
tst_date  = dm_dates[ len(dm_dates)]

# ensure DM is prepared
for (dmdate in c(trn_dates, tst_date)) {
  assert(system2("Rscript", c("src/dm-prep.R", expname, dmdate)) == 0)
}

# load DM for this step
loginfo("Load DM")
load_d = function(d, what) {
  dfile = glue("{expdir}/dm/{d}/{what}.qs")
  qload(dfile)
}

load_x = function(d) load_d(d, "x")
load_y = function(d) load_d(d, "y")
load_b = function(d) load_d(d, "b")

trn_x = mapreduce(trn_dates, load_x, rbind, progmsg = "load trn_x")
trn_y = mapreduce(trn_dates, load_y, c, progmsg = "load trn_y")
trn_b = mapreduce(trn_dates, load_b, c, progmsg = "load trn_b")

trn =
  xgb.DMatrix(
    trn_x,
    info = list(
      label = trn_y,
      base_margin = trn_b
    )
  )

loginfo("TRN set loaded: (%i rows, %i cols, %s)", nrow(trn_x), ncol(trn_x), object_size_str(trn_x))

tst_x = load_x(tst_date)
tst_y = load_y(tst_date)
tst_b = load_b(tst_date)

tst =
  xgb.DMatrix(
    tst_x,
    info = list(
      label = tst_y,
      base_margin = tst_b
    )
  )

loginfo("TST set loaded: (%i rows, %i cols, %s)", nrow(tst_x), ncol(tst_x), object_size_str(tst_x))

params = this_run[["params"]][[1]]
loginfo("Using the following params")
for (n in names(params)) {
  cat("  ", n, " = ", params[[n]], "\n",  sep = "")
}

loginfo("Begin training")

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

loginfo("Training complete! Best iteration was:")
best_training_round = mdl$evaluation_log[which(tst_rmse == min(tst_rmse))]
print(best_training_round)

param_id = this_run[["param_id"]]
rundir = glue("{expdir}/cv/params/{param_id}/rounds/{round_id}/runs/{run_id}")
dir.create(rundir, recursive = TRUE, showWarnings = FALSE)

loginfo("Saving artifacts.")
save_art = function(art) {
  art_name = deparse(substitute(art))
  art_qs = glue("{rundir}/{art_name}.qs")
  loginfo("Saving %s to %s", art_name, art_qs)
  qsave(art, art_qs)
}

save_art(mdl)
save_art(trn_x)
save_art(trn_y)
save_art(trn_b)

save_art(tst_x)
save_art(tst_y)
save_art(tst_b)

# record that this step is done
rowid = this_run[["rowid"]]
cvdb[rowid,"done"] <- TRUE
cvdb[rowid,"tst_rmse"] <- best_training_round[1,"tst_rmse"]

loginfo("Step complete.")

# define some stuff for post-step callback
new_rowid = function() max(cvdb[["rowid"]], na.rm = TRUE) + 1L
new_param_id = function() {
  max(cvdb[["param_id"]], na.rm = TRUE) + 1L
}

next_run_id = function() this_run[["run_id"]] + 1L
next_round_id = function() this_run[["round_id"]] + 1L

run_is_complete = function() {
  cvdb %>%
    filter(run_id == this_run[["run_id"]]) %>%
    pull(done) %>%
    all()
}

round_is_complete = function() {
  cvdb %>%
    filter(round_id == this_run[["round_id"]]) %>%
    pull(done) %>%
    all()
}

add_params_for_next_run = function(p) {
  newid = new_rowid()
  cvdb[newid,"rowid"] <<- newid
  cvdb[newid,"round_id"] <<- this_run[["round_id"]]
  cvdb[newid,"run_id"] <<- next_run_id()
  cvdb[newid,"param_id"] <<- new_param_id()
  cvdb[newid,"params"] <<- list(list(p))
  cvdb[newid,"done"] <<- FALSE
}

add_params_for_this_run = function(p) {
  newid = new_rowid()
  cvdb[newid,"rowid"] <<- newid
  cvdb[newid,"round_id"] <<- this_run[["round_id"]]
  cvdb[newid,"run_id"] <<- this_run[["run_id"]]
  cvdb[newid,"param_id"] <<- new_param_id()
  cvdb[newid,"params"] <<- list(list(p))
  cvdb[newid,"done"] <<- FALSE
}

# run post-step callback
# can do anything; e.g random search would add new parameter sets to try
# bayesOpt would do it's bayes-y thing and add new parameter sets to try
# for genetic algorithm; would summarise once all runs in a round are complete,
# then generate new params to try, with incremented round id
print(cvdb)
loginfo("Invoke step-end callback")
config_env[["cb_step_end"]]()
print(cvdb)

# writeback cvdb
qsave(cvdb, cvdb_qs)

