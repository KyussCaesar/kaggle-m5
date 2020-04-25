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
