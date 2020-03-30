redo_load(
  df = "sales_train_validation.csv.rds",
  depts = "depts.rds",
  cats = "cats.rds"
)

loginfo("create items lookup")
df_out =
  df %>%
  lazy_dt() %>%
  count(item_id, dept_id, cat_id) %>%
  arrange(desc(n)) %>%
  transmute(
    item_name = item_id,
    dept_name = dept_id,
    cat_name  = cat_id,
    item_id = 1:n()
  ) %>%
  left_join(depts, by = c("dept_name")) %>%
  left_join(cats, by = c("cat_name")) %>%
  select(
    item_id,
    item_name,
    dept_id,
    cat_id
  ) %>%
  as.data.table()

df_out
setkey(df_out, "item_id")
setindex(df_out, "item_name")
setindex(df_out, "dept_id")
setindex(df_out, "cat_id")
