redo_load(
  sales = "sales.qs"
)

df_out =
  sales %>%
  lazy_dt() %>%
  select(target_id, d, volume) %>%
  filter(volume != 0) %>%
  group_by(target_id) %>%
  summarise(launch_date_i = min(d)) %>%
  as.data.table()

setkey(df_out, "target_id")
