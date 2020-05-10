list_features = function() {
  tibble(
    root = sort(system2("find", c("features", "-mindepth", "2", "-maxdepth", "2", "-type", "f", "-name", "build-end"), stdout = TRUE)),
    feature_dir = dirname(root),
    feature_name = basename(feature_dir)
  )
}

fts = list_features()
fts
View(fts)

round_id = 1
run_id = 1

base_seed = 999
n_dates = 10
set.seed(base_seed + round_id)
# ensure we have at least enough space for 1M runs
# should be enough?
set.seed(floor(runif(1, min = 0, max = .Machine$integer.max - 1048576)) + run_id)
dm_dates = sort(sample(1:1855, n_dates, prob = 1:1855))
dm_dates[len(dm_dates) + 1] = dm_dates[len(dm_dates)] + 28
dm_dates

hc_cvdb = qload("experiments/test-b-hillclimber/cv/cvdb.qs")
hc_cvdb %>% View()

params_by_round =
  hc_cvdb %>%
  filter(done) %>%
  group_by(param_id, round_id) %>%
  summarise(tst_rmse = mean(tst_rmse)) %>%
  ungroup() %>%
  arrange(tst_rmse)

params_by_round %>%
  arrange(param_id) %>%
  transmute(param_id, tst_rmse, chng = c(0, diff(tst_rmse)))

p =
  hc_cvdb %>%
  filter(done) %>%
  mutate(
    direction_0 = map(map(hc_state, pluck, "hc_direction"), as_tibble),
    direction_1 = lag(direction_0)
  ) %>%
  filter(param_id != 1, param_id != 2) %>%
  transmute(
    param_id,
    tst_rmse,
    vecdiff = pmap(list(direction_0, direction_1), function(x1, x2) {
      mag = function(x) sqrt(sum(x*x))
      dot = function(u, v) sum(u * v)

      u = as.numeric(x1)
      v = as.numeric(x2)

      angle = dot(u,v) %>% `/`(mag(u)*mag(v)) %>% clamp(-1, 1) %>% acos() %>% `*`(180) %>% `/`(pi)
    })
  ) %>%
  unnest(vecdiff) %>%
  pivot_longer(-param_id) %>%
  ggplot(aes(x = param_id, y = value)) +
  geom_line() +
  facet_wrap(~name, ncol = 1, scales = "free")

ggplotly(p)

hc_cvdb %>%
  filter(param_id %in% c(35, 76, 109)) %>%
  transmute(
    tst_rmse = tst_rmse - 2.2,
    param_id = glue("param_id={param_id}"),
    params = map(params, as_tibble)
  ) %>%
  unnest(params) %>%
  select(-lambda, -alpha, -tree_method, -sampling_method, -max_delta_step, -nthread) %>%
  pivot_longer(-param_id) %>%
  ggplot(aes(x = param_id, y = value, fill = param_id)) +
  geom_col() +
  facet_wrap(~name, ncol = 4, scales = "free")

make_initial_params = function(pms) {
  cat("list(\n  ")
  nns = vector(mode = "character", length = len(pms))
  ns = names(pms)

  for (i in seq_along(ns)) {
    nns[i] <- glue("{ns[i]} = {pms[[ns[i]]]}")
  }

  cat(nns, sep = ",\n  ")
  cat("\n)")
}

hc_cvdb %>% filter(param_id == 35) %>% pull(params) %>% `[[`(1) %>% make_initial_params()

dm_1003_x = qload("experiments/test-c-hillclimber2/dm/1003/x.qs")
dm_1003_x

dms =
  tibble(
    ffs = list.files("experiments/test-c-hillclimber2/dm", full.names = TRUE),
    ncols = sapply(ffs, function(x) qload(glue("{x}/x.qs")) %>% ncol())
  )

dms %>% View()

# ----
# Checking out the results from first run of test-c

expname = "test-c-hillclimber2"
expdir  = glue("experiments/{expname}")
cvdb = qload(glue("{expdir}/cv/cvdb.qs"))
cvdb

load_artifact = function(cvdb, what) {
  param_id = cvdb[["param_id"]]
  round_id = cvdb[["round_id"]]
  run_id   = cvdb[["run_id"]]

  qload(glue("{expdir}/cv/params/{param_id}/rounds/{round_id}/runs/{run_id}/{what}.qs"))
}

mdl =
  cvdb %>%
  filter(param_id == 1) %>%
  load_artifact("mdl") %>%
  xgb.Booster.complete()

tst_x =
  cvdb %>%
  filter(param_id == 1) %>%
  load_artifact("tst_x")

tst_y =
  cvdb %>%
  filter(param_id == 1) %>%
  load_artifact("tst_y")

tst_x

best_iter = function(mdl) {
  mdl$evaluation_log[tst_rmse == min(tst_rmse), iter]
}

importance_from_best = function(mdl) {
  xgb.importance(model = mdl, trees = seq(0, mdl$best_ntreelimit - 1))
}

predict_from_best = function(mdl, data) {
  # NB: we have num_parallel_tree trees per boosting iteration
  predict(mdl, data, ntreelimit = mdl$best_ntreelimit)
}

mdlimp = importance_from_best(mdl)
tst_pred = predict_from_best(mdl, tst_x)

rms(tst_y - tst_pred)

tst_x

mdl$evaluation_log[tst_rmse == min(tst_rmse)]

plot_deepness = xgb.ggplot.deepness(model = mdl) %>% print()
plot_importance = xgb.ggplot.importance(importance_matrix = importance_from_best(mdl)) %>% print()
plot_eval = mdl$evaluation_log %>% pivot_longer(-iter) %>% plotf(value ~ iter + name, geom=geom_line) %>% print()
