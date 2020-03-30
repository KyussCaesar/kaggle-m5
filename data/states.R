redo_load(
  df = "sales_train_validation.csv.rds"
)

loginfo("create states lookup")
df_out =
  df %>%
  lazy_dt() %>%
  select(state_id, store_id) %>%
  group_by(state_id) %>%
  summarise(
    state_n = n(),
    n_stores_in_state = cardinality(store_id)
  ) %>%
  arrange(desc(state_n)) %>%
  transmute(
    state_name = state_id,
    state_id = 1:n(),
    n_stores_in_state,
  ) %>%
  select(state_id, state_name, n_stores_in_state) %>%
  as.data.table()

df_out
setkey(df_out, "state_id")
setindex(df_out, "state_name")

