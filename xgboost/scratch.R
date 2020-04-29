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
