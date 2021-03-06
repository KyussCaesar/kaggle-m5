redo_load(
  df = "sales_train_validation.csv.qs",
  states = "states.qs",
  cats = "cats.qs",
  depts = "depts.qs",
  stores = "stores.qs",
  items = "items.qs",
  targets = "targets.qs",
  prices = "prices.qs"
)

loginfo("create sales lookup")
df_out =
  df %>%
  lazy_dt() %>%
  # replace all of the names with integer IDs
  select(
    target_name = id,
    item_name = item_id,
    cat_name = cat_id,
    dept_name = dept_id,
    store_name = store_id,
    state_name = state_id,
    starts_with("d_")
  ) %>%
  left_join(targets[,c("target_id", "target_name")], by = c("target_name")) %>%
  left_join(  items[,c("item_id"  , "item_name"  )], by = c("item_name"  )) %>%
  left_join(   cats[,c("cat_id"   , "cat_name"   )], by = c("cat_name"   )) %>%
  left_join(  depts[,c("dept_id"  , "dept_name"  )], by = c("dept_name"  )) %>%
  left_join( stores[,c("store_id" , "store_name" )], by = c("store_name" )) %>%
  left_join( states[,c("state_id" , "state_name" )], by = c("state_name" )) %>%
  select(-ends_with("_name")) %>%
  # gather/pivot_longer are not implemented in dtplyr :(
  as.data.table() %>%
  melt(measure.vars = patterns("d_")) %>%
  lazy_dt() %>%
  mutate(
    d = as.integer(sub("d_", "", variable)),
    volume = as.integer(value)
  ) %>%
  select(-variable, -value) %>%
  arrange() %>%
  as.data.table()

df_out = merge(df_out, prices, by = c("d", "item_id", "store_id"), all.x = TRUE)
df_out[, trnovr := volume * price]

df_out
setkey(df_out, "target_id")
setindex(df_out, "item_id")
setindex(df_out, "store_id")
setindex(df_out, "d")
