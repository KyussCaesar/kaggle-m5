redo_load(
  df = "sales_train_validation.csv.rds"
)

loginfo("create cats lookup")
df_out =
  df %>%
  lazy_dt() %>%
  count(cat_id) %>%
  arrange(desc(n)) %>%
  transmute(
    cat_name = cat_id,
    cat_id = 1:n()
  ) %>%
  select(cat_id, cat_name) %>%
  as.data.table()

df_out
setkey(df_out, "cat_id")
setindex(df_out, "cat_name")
