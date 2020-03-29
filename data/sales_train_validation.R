
loginfo("create states lookup")
states =
  df %>%
  count(state_id) %>%
  arrange(desc(n)) %>%
  transmute(
    state_name = state_id,
    state_id = 1:n()
  ) %>%
  select(state_id, state_name) %>%
  as.data.table()

states
setkey(states, "state_id")
setindex(states, "state_name")

loginfo("create cats lookup")
cats =
  df %>%
  count(cat_id) %>%
  arrange(desc(n)) %>%
  transmute(
    cat_name = cat_id,
    cat_id = 1:n()
  ) %>%
  select(cat_id, cat_name) %>%
  as.data.table()

cats
setkey(cats, "cat_id")
setindex(cats, "cat_name")

loginfo("create depts lookup")
depts =
  df %>%
  count(dept_id) %>%
  arrange(desc(n)) %>%
  transmute(
    dept_name = dept_id,
    dept_id = 1:n()
  ) %>%
  select(dept_id, dept_name) %>%
  as.data.table()

depts
setkey(depts, "dept_id")
setindex(depts, "dept_name")

loginfo("create stores lookup")
stores =
  df %>%
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

stores
setkey(stores, "store_id")
setindex(stores, "store_name")
setindex(stores, "state_id")

loginfo("create items lookup")
items =
  df %>%
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

items
setkey(items, "item_id")
setindex(items, "item_name")
setindex(items, "dept_id")
setindex(items, "cat_id")

targets =
  df %>%
  count(id) %>%
  arrange(desc(n)) %>%
  transmute(
    target_name = id,
    target_id = 1:n()
  ) %>%
  select(target_id, target_name) %>%
  as.data.table()

targets
setkey(targets, "target_id")
setindex(targets, "target_name")

loginfo("convert sales_train")
sales =
  df %>%
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

sales
setkey(sales, "target_id")
setindex(sales, "item_id")
setindex(sales, "store_id")
setindex(sales, "d")

df_out =
  list(
    states  = states,
    cats    = cats,
    depts   = depts,
    stores  = stores,
    items   = items,
    targets = targets,
    sales   = sales
  )
