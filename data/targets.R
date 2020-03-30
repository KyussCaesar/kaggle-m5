redo_load(
  df = "sales_train_validation.csv.rds"
)

loginfo("create targets lookup")
df_out =
  df %>%
  lazy_dt() %>%
  count(id) %>%
  arrange(desc(n)) %>%
  transmute(
    target_name = id,
    target_id = 1:n()
  ) %>%
  select(target_id, target_name) %>%
  as.data.table()

df_out
setkey(df_out, "target_id")
setindex(df_out, "target_name")
