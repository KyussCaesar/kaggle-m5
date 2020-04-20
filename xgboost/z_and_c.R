redo_load(
  sales = here("data/sales.rds")
)

mk_ids = compiler::cmpfun(function(...) {
  loginfo("Create ID lookup for (%s)", paste(..., sep = ","))

  df =
    sales %>%
    data.table::copy() %>%
    lazy_dt(immutable = FALSE) %>%
    select_at(c(...)) %>%
    distinct() %>%
    mutate(
      id = 1:n()
    ) %>%
    select_at(c("id", ...)) %>%
    as.data.table()

  df
})

# mapping (heirarchy level) -> (indexes for each component of that level)
C =
  list(
    all_ids        = data.table(id = 1, all_id = 1), # all
    state_ids      = mk_ids("state_id"),             # by state
    store_ids      = mk_ids("store_id"),             # by store
    cat_ids        = mk_ids("cat_id"),               # by category
    dept_ids       = mk_ids("dept_id"),              # by department
    state_cat_ids  = mk_ids("state_id", "cat_id"),   # by (state, category)
    state_dept_ids = mk_ids("state_id", "dept_id"),  # by (state, department)
    store_cat_ids  = mk_ids("store_id", "cat_id"),   # by (store, category)
    store_dept_ids = mk_ids("store_id", "dept_id"),  # by (store, deparment)
    item_ids       = mk_ids("item_id"),              # by item
    item_state_ids = mk_ids("item_id", "state_id"),  # by (item, state)
    item_store_ids = mk_ids("item_id", "store_id")   # by (item, store)
  )

attach(C)

# mapping between
# (level, component id) -> (set of i's in I that make up that component)
# NOTE: disabled for now; only needed for calculating weightings/WRMSSE
Z =
  tibble(l = L) %>%
  mutate(
    c_l = map(l, function(l) C[[l]][,id])
  ) %>%
  unnest("c_l") %>%
  mutate(
    z_c = pmap(list(l, c_l), function(l, c_l) {
      lname = names(C)[[l]]
      ldata = C[[l]][id == c_l]
      df = NULL

      if (lname == "all_ids") df = item_store_ids;

      if (lname == "state_ids") {
        # use stores table to map state -> stores in that state -> targets for those stores
        df =
          ldata[,"state_id"] %>%
          merge(        stores[,c("state_id", "store_id")], all.x = TRUE, by = "state_id") %>%
          merge(item_store_ids[,c("store_id", "id"      )], all.x = TRUE, by = "store_id")
      }

      if (lname == "store_ids") {
        df =
          ldata[,"store_id"] %>%
          merge(item_store_ids[,c("store_id", "id")], all.x = TRUE, by = "store_id")
      }

      if (lname == "cat_ids") {
        df =
          ldata[,"cat_id"] %>%
          merge(         items[,c("cat_id" , "item_id"       )], all.x = TRUE, by = "cat_id" ) %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = "item_id")
      }

      if (lname == "dept_ids") {
        df =
          ldata[,"dept_id"] %>%
          merge(         items[,c("dept_id", "item_id"       )], all.x = TRUE, by = "dept_id") %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = "item_id")
      }

      if (lname == "state_cat_ids") {
        df =
          ldata[,c("state_id", "cat_id")] %>%
          merge(         items[,c("cat_id" , "item_id"       )], all.x = TRUE, by = "cat_id") %>%
          merge(        stores[,c("state_id", "store_id"     )], all.x = TRUE, by = "state_id", allow.cartesian = TRUE) %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = c("item_id", "store_id"))
      }

      if (lname == "state_dept_ids") {
        df =
          ldata[,c("state_id", "dept_id")] %>%
          merge(         items[,c("dept_id" , "item_id"      )], all.x = TRUE, by = "dept_id") %>%
          merge(        stores[,c("state_id", "store_id"     )], all.x = TRUE, by = "state_id", allow.cartesian = TRUE) %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = c("item_id", "store_id"))
      }

      if (lname == "store_cat_ids") {
        df =
          ldata[,c("store_id", "cat_id")] %>%
          merge(         items[,c("cat_id", "item_id"        )], all.x = TRUE, by = "cat_id") %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = c("item_id", "store_id"))
      }

      if (lname == "store_dept_ids") {
        df =
          ldata[,c("store_id", "dept_id")] %>%
          merge(         items[,c("dept_id" , "item_id"      )], all.x = TRUE, by = "dept_id") %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = c("item_id", "store_id"))
      }

      if (lname == "item_ids") {
        df =
          ldata[,"item_id"] %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = "item_id")
      }

      if (lname == "item_state_ids") {
        df =
          ldata[,c("item_id", "state_id")] %>%
          merge(stores[,c("state_id", "store_id")], all.x = TRUE, by = "state_id", allow.cartesian = TRUE) %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = c("item_id", "store_id"))
      }

      if (lname == "item_store_ids") {
        df =
          ldata[,c("item_id", "store_id")] %>%
          merge(item_store_ids[,c("item_id", "store_id", "id")], all.x = TRUE, by = c("item_id", "store_id"))
      }

      if (is.null(df)) stop("df is null") # bad error message, should improve it
      df[,id]
    })
  ) %>%
  unnest(cols = "z_c") %>%
  as.data.table()

I = item_store_ids[,id]
