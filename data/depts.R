redo_load(
  df = "sales_train_validation.csv.rds"
)

loginfo("create depts lookup")
df_out =
  df %>%
  lazy_dt() %>%
  count(dept_id) %>%
  arrange(desc(n)) %>%
  transmute(
    dept_name = dept_id,
    dept_id = 1:n()
  ) %>%
  select(dept_id, dept_name) %>%
  as.data.table()

df_out
setkey(df_out, "dept_id")
setindex(df_out, "dept_name")
