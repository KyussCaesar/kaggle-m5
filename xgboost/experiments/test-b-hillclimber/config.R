# configuration for the experiment
# should define some variables:
#

initial_params =
  list(
    nthread = 8,
    eta = 0.3,
    gamma = 1,
    max_depth = 3,
    min_child_weight = 1,
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

# CVDB table should look like this
#
#   round_id: int  id for the round
#   run_id  : int  id for the run in that round
#   param_id: int  id for the parameter set
#   params  : list params to use for that round
#   done    : bool has that step been run already?
initial_cvdb =
  tibble(
    rowid = 1,
    round_id = 1,
    run_id = 1,
    param_id = 1,
    params = list(initial_params),
    done = FALSE
  )

# base_seed: int seed for generating run dates
base_seed = 999

# n_dates: int number of training dates for each run
n_dates = 8

hc_max_rounds = 1
hc_max_runs = 1    # ...per round
hc_max_params = 10 # ...per run
hc_seed = 34079

new_hc_direction = function(round_id, run_id, param_id) {
  old.seed = .Random.seed
  set.seed(hc_seed)
  set.seed(floor(runif(1, min = 0, max = .Machine$integer.max - 1048576)) + round_id)
  set.seed(floor(runif(1, min = 0, max = .Machine$integer.max - 1048576)) + run_id)
  set.seed(floor(runif(1, min = 0, max = .Machine$integer.max - 1048576)) + param_id)

  hc_direction =
    list(
      d_eta               = rnorm(1, sd = 0.01),
      pc_gamma            = rnorm(1, mean = 1, sd = 0.06),
      d_max_depth         = sample(c(-1, 0, 1), 1),
      pc_min_child_weight = rnorm(1, mean = 1, sd = 0.06),
      d_subsample         = rnorm(1, sd = 0.01),
      d_colsample_bytree  = rnorm(1, sd = 0.001),
      d_colsample_bylevel = rnorm(1, sd = 0.001),
      d_colsample_bynode  = rnorm(1, sd = 0.001),
      d_num_parallel_tree   = sample(c(-1, 0, 1), 1)
    )

  .Random.seed = old.seed

  hc_direction
}

hc_step = function(params, hc_direction) {
  loginfo("Old params")
  print(params)

  newparams =
    list(
      nthread           =       params[["nthread"]],
      eta               = clamp(params[["eta"]]               + hc_direction[["d_eta"]]              , 0, 1   ),
      gamma             = clamp(params[["gamma"]]             * hc_direction[["pc_gamma"]]           , 0, NULL),
      max_depth         = clamp(params[["max_depth"]]         + hc_direction[["d_max_depth"]]        , 1, NULL),
      min_child_weight  = clamp(params[["min_child_weight"]]  * hc_direction[["pc_min_child_weight"]], 0, NULL),
      max_delta_step    =       params[["max_delta_step"]],
      subsample         = clamp(params[["subsample"]]         + hc_direction[["d_subsample"]]        , 0, 1   ),
      sampling_method   =       params[["sampling_method"]],
      colsample_bytree  = clamp(params[["colsample_bytree"]]  + hc_direction[["d_colsample_bytree"]] , 0, 1   ),
      colsample_bylevel = clamp(params[["colsample_bylevel"]] + hc_direction[["d_colsample_bylevel"]], 0, 1   ),
      colsample_bynode  = clamp(params[["colsample_bynode"]]  + hc_direction[["d_colsample_bynode"]] , 0, 1   ),
      lambda            =       params[["lambda"]],
      alpha             =       params[["alpha"]],
      tree_method       =       params[["tree_method"]],
      num_parallel_tree = clamp(params[["num_parallel_tree"]] + hc_direction[["d_num_parallel_tree"]], 1, NULL)
    )

  loginfo("New params")
  print(newparams)
  newparams
}

# cb_step_end: \().() callback invoked at the end of each CV step.
cb_step_end = function() {
  round_id = this_run[["round_id"]]
  run_id = this_run[["run_id"]]
  param_id = this_run[["param_id"]]
  params = this_run[["params"]][[1]]

  hc_state = this_run[["hc_state"]][[1]]
  if (is.null(hc_state)) {
    hc_state =
      list(
        hc_direction = NULL,
        prev_score = 0
      )
  }

  # if this score is worse than prev. paramset score, pick a new direction
  this_score =
    cvdb %>%
    filter(round_id == {{ round_id }} & run_id == {{ run_id }} & param_id == {{ param_id }}) %>%
    pull(tst_rmse)

  assert(!is.null(this_score))
  assert(len(this_score) == 1)

  if (this_score > hc_state[["prev_score"]]) {
    # score got worse; pick new direction
    hc_state[["hc_direction"]] = new_hc_direction(round_id, run_id, param_id)
  }

  hc_state[["prev_score"]] = this_score

  # perform hillclimber step
  newparams = hc_step(params, hc_state[["hc_direction"]])

  newid = new_rowid()
  cvdb[newid,"rowid"] <<- newid
  cvdb[newid,"round_id"] <<- this_run[["round_id"]]
  cvdb[newid,"run_id"] <<- this_run[["run_id"]]
  cvdb[newid,"param_id"] <<- new_param_id()
  cvdb[newid,"params"] <<- list(list(newparams))
  cvdb[newid,"hc_state"] <<- list(list(hc_state))
  cvdb[newid,"done"] <<- FALSE
}
