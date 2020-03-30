redo_load(
  df = "sales_train_validation.csv.rds",
  states = "states.rds"
)

loginfo("create stores lookup")
df_out =
  df %>%
  lazy_dt() %>%
  count(store_id, state_id) %>%
  arrange(desc(n)) %>%
  transmute(
    store_name = store_id,
    state_name = state_id,
    store_id = 1:n()
  ) %>%
  left_join(states, by = c("state_name")) %>%
  group_by(state_id) %>%
  mutate(store_id_state = 1:n()) %>%
  select(
    store_id,
    store_name,
    state_id,
    store_id_state
  ) %>%
  ungroup() %>%
  as.data.table()

df_out
setkey(df_out, "store_id")
setindex(df_out, "store_name")
setindex(df_out, "state_id")
