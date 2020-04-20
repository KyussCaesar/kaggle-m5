var2key =
  c(
    "cat" = "cat_id",
    "stt" = "state_id",
    "dpt" = "dept_id",
    "str" = "store_id",
    "itm" = "item_id",
    "tgt" = "target_id"
  )

fspec =
  tibble(
    feature_name =
      system2(
        "/bin/bash",
        input = "echo {tgt,itm,str,stt,cat,dpt}_{volume,trnovr}_{cumsum,yoy_{1,2},mom_{1,2,3,6,12},wow_{1,2,4},{trend,roll{mean,max,sum,countzeros}r}_{7,14,28,84,182}} | tr ' ' '\n'",
        stdout = TRUE
      )
  ) %>%
  separate(feature_name, c("agg_var", "agg_val", "func", "arg"), remove = FALSE) %>%
  transmute(
    agg_var,
    func,
    fgen = sub("^", "      ", paste0(feature_name, " = mk_", func, "(", agg_var, "_", agg_val, ", ", arg, ")"))
  )

reload("sales")

skiplen = 500

#agg_var = "cat"
for (agg_var in names(var2key)) {

  f1 =
    fspec %>%
    filter(agg_var == {{ agg_var }})

  agg_key = unnamed(var2key[agg_var])

  agg_key_ids = sort(unique(sales[[agg_key]]))

  ci = seq(1, len(agg_key_ids), skiplen)
  #fnfmt = paste0("%s/", agg_var, "/fgen", "-%0", floor(log10(max(ci))) + 1, "i.%s")
  fnfmt = paste0("%s/", agg_var, "/%s/", "%0", floor(log10(max(ci))) + 1, "i.%s")

  #i = 1
  for (i in ci) {

    c_beg = i
    c_end = min(i + skiplen - 1, len(agg_key_ids))

    #func = "cumsum"
    for (func in unique(f1[["func"]])) {

      features =
        f1 %>%
        filter(func == {{ func }}) %>%
        pull(fgen) %>%
        paste0(collapse = ",\n")

      rscript_src = sprintf(fnfmt, "src", func, i, "R")
      rscript_out = sprintf(fnfmt, "data", func, i, "qs")

      dir.create(dirname(rscript_src), recursive = TRUE, showWarnings = FALSE)

      # NOTES: could speed this up quite a bit:
      # - sales are loaded fresh each time; instead of being totally independent,
      #   could instead spawn workers that keep sales in-memory
      # - sales are cut down repeatedly each time; could cut down once ahead of time,
      #   then generate scripts that only read in the already-cut versions.
      # - source the functions each time; might get small speedup by only sourcing what
      #   is needed, or by re-defining in each generated script.

      fmt = "
      dir.create(dirname(\"{rscript_out}\"), recursive = TRUE, showWarnings = FALSE)
      if (file.exists(\"{rscript_out}\")) quit(save = \"no\", status = 0)

      source(\"feature-generators.R\")

      sales = qload(here(\"data/sales.qs\"))

      s_{agg_var} =
        sales[
          {agg_key} >= {agg_key_ids[c_beg]} &
          {agg_key} <=  {agg_key_ids[c_end]},
          .(
            {agg_var}_volume = sum(volume, na.rm = TRUE),
            {agg_var}_trnovr = sum(trnovr, na.rm = TRUE)
          ),
          keyby = .(d, {agg_key})
        ][
          order(d),
          .(
            d,
      {features}
          ),
          keyby = {agg_key}
        ]

      setkey(s_{agg_var}, \"d\", \"{agg_key}\")
      qsave(s_{agg_var}, \"{rscript_out}\")
      "

      cmd = glue(fmt)
      cat(cmd, file = file(rscript_src, "wt"))
      compiler::cmpfile(rscript_src)
    }

  }

}

