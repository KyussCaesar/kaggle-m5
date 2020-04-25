loginfo("Prepare feature generators")

var2key =
  c(
    "cat" = "cat_id",
    "stt" = "state_id",
    "dpt" = "dept_id",
    "str" = "store_id",
    "itm" = "item_id",
    "tgt" = "target_id"
  )

loginfo("Define feature spec")
fspec =
  tibble(
    feature_name =
      system2(
        "/bin/bash",
        input = "echo {tgt,itm,str,stt,cat,dpt}_{volume,trnovr}_sum_{cumsum,yoy_{1,2},mom_{1,2,3,6,12},wow_{1,2,4},{trend,roll{mean,max,sum,countzeros,rms}r}_{7,14,28,84,182},arimaw_{2,4,8},s{naive_{1,2,7,14},wow_{2,4,8},mom_{2,4,6},yoy_{1,2}}} | tr ' ' '\n'",
        stdout = TRUE
      )
  ) %>%
  separate(feature_name, c("agg_key", "agg_val", "agg_fun", "ftr_nme", "ftr_arg"), remove = FALSE) %>%
  mutate(
    agg_var = unnamed(var2key[agg_key]),
    agg_ser = paste(agg_key, agg_val, agg_fun, sep = "_"),
    ftr_mkr = glue("mk_{ftr_nme}"),
    create_series = glue("{agg_ser} = {agg_fun}({agg_val}, na.rm = TRUE)"),
    create_feature = glue("[order(d), .(d, {feature_name} = {ftr_mkr}({agg_ser}, {ftr_arg})), keyby = .({agg_var})]"),
  )

loginfo("Load sales")
reload("sales")

# create the output directories ahead of time
# easier than doing it on-the-fly, and _much_ faster
# my machine churns through ~6500 directories per second
# completing 1.1 million in about 3 minutes
# by comparison, the naiive approach of repeatedly calling `dir.create`
# would take about 17 minutes
mk_output_dirs = function() {
  loginfo("create output dirs")
  # create directories in batches of this size
  # make it as large as possible, without the command line being too long.
  buflen = 2560
  buf = vector(mode = "character", length = buflen)
  bufi = 0

  # TODO: need to add the out-of-sample dates here too
  dates = sort(unique(sales[,d]))
  ftrs = sort(unique(fspec[["feature_name"]]))

  pb = mkbar("create output dirs", len(dates) * len(ftrs))
  pb$tick(0)

  for (ftrnm in ftrs) {
    for (d in dates) {
      bufi = bufi + 1
      buf[[bufi]] = glue("features/{ftrnm}/{d}")

      if (bufi == buflen) {
        assert(system(paste0(c("mkdir", "-p", buf), collapse = " ")) == 0)

        pb$tick(bufi)
        buf = vector(mode = "character", length = buflen)
        bufi = 0

      }
    }
  }

  if (bufi != 0) {
    assert(system(paste0(c("mkdir", "-p", buf), collapse = " ")) == 0)
    pb$tick(bufi)
    buf = vector(mode = "character", length = buflen)
    bufi = 0
  }
}

# mk_output_dirs()

#agg_key = "itm"
for (agg_key in unique(fspec[["agg_key"]])) {
  loginfo("Begin processing %s", agg_key)
  agg_var = unnamed(var2key[agg_key])

  ids = sort(unique(sales[[agg_var]]))

  skiplen = 500
  ci = seq(1, len(ids), skiplen)

  series_2_mk =
    fspec %>%
    filter(agg_key == {{ agg_key }}) %>%
    pull(create_series) %>%
    unique() %>%
    sort() %>%
    paste0(collapse = ",\n")

  dir.create(glue("aggs/{agg_key}"), recursive = TRUE, showWarnings = FALSE)

  #i = 1
  for (i in ci) {
    gc(full = TRUE)

    c_beg = i
    c_end = min(i + skiplen - 1, len(ids))

    aggfile = glue("aggs/{agg_key}/{i}")
    src_agg_sale ="
    qsave(
      qload(here(\"data/sales.qs\"))[
        {agg_var} >= {ids[c_beg]} &
        {agg_var} <= {ids[c_end]} ,
      .(
    {series_2_mk}
      ),
      keyby = .(d, {agg_var})
      ],
      \"{aggfile}\"
    )
    "

    cmd = glue(src_agg_sale)
    cat(cmd, file = glue("{aggfile}-mk.R"))

    features_2_mk =
      fspec %>%
      filter(agg_key == {{ agg_key }}) %>%
      select(ftrmk = create_feature, feature_name) %>%
      as.data.table()

    #k = 1
    for (k in 1:nrow(features_2_mk)) {
      ftrmk = features_2_mk[k,ftrmk]
      ftrnm = features_2_mk[k,feature_name]

      dir.create(glue("features/{ftrnm}"), recursive = TRUE, showWarnings = FALSE)
      ftrfile = glue("features/{ftrnm}/{i}-mk.R")

      # TODO: pretty sure this won't handle out-of-sample dates properly
      cat(
        "source(\"feature-generators.R\")\n",
        "invisible(",
        glue("qload(\"{aggfile}\"){ftrmk}"),
        glue("[,qsave(.SD, paste0(\"features/{ftrnm}/\", d, \"/{i}\") ), keyby = d]"),
        ")",
        file = ftrfile,
        sep = ""
      )
    }

    loginfo("Done processing chunk %i for %s", i, agg_key)
  }

  loginfo("Done processing %s", agg_key)
}
