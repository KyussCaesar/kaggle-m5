argv = commandArgs(TRUE)
expname = argv[1]
expdir = glue("experiments/{expname}")
dmdate = as.integer(argv[2])

if (!dir.exists(expdir)) {
  logerror("dm-prep.R: the specified experiment directory (%s) does not exist", expdir)
}

loginfo("Prepare DM for:")
debugit(expname)
debugit(expdir)
debugit(dmdate)

# before we do anything; check if output already exists
dm_dest_dir = glue("{expdir}/dm/{dmdate}")
dir.create(dm_dest_dir, recursive = TRUE, showWarnings = FALSE)

dm_dest_x = glue("{dm_dest_dir}/x.qs")
dm_dest_y = glue("{dm_dest_dir}/y.qs")
dm_dest_b = glue("{dm_dest_dir}/b.qs")

outputs = c(dm_dest_x, dm_dest_y, dm_dest_b)

preexisting = file.exists(outputs)
if (all(preexisting)) {
  logwarn("All outputs already exist; early stop")
  quit(status = 0, save = "no")
} else if (any(preexisting)) {
  logwarn("Some outputs already exist; remove them and rebuild")
  file.remove(outputs)
}

# Read feature spec
features_env = new.env()
features_src = glue("{expdir}/features.R")
source(features_src, local = features_env, chdir = TRUE)

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

    load_from = glue("{load_dir}/{d}-merged")

    if (!file.exists(load_from)) {
      if (d != 1) {
        # feature does not exist for that day
        # assume we are building features for the validation/evaluation set
        # so just return empty df
        # using d = 1 as a template
        warning(feature_name, " has not been built for d = ", d, ": will use empty frame instead")
        df = load_d(feature_name, 1)[1,]
        df[,] <- NA
      } else {
        stop(feature_name, " has not been built for d = ", d, ": cannot proceed")
      }

    } else {
      df = qload(load_from)

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
      rbind#, progmsg = "load dm skeleton"
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
    debugit(feature_name)
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


# Create DM
dm = create_dm(features_env[["features"]], dmdate)
dm_x = as.matrix(dm[,-"volume", with = FALSE])
dm_y = as.matrix(dm[, "volume"])
dm_b = as.matrix(rep(0, nrow(dm_x)))

qsave(dm_x, dm_dest_x)
qsave(dm_y, dm_dest_y)
qsave(dm_b, dm_dest_b)
