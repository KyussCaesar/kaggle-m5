stores = readRDS("stores.sales_train_validation.extract.rds")
items  = readRDS("items.sales_train_validation.extract.rds")
dates  = readRDS("dates.calendar.extract.rds")

sell_prices_min =
  df %>%
  transmute(
    store_name = store_id,
    item_name = item_id,
    wm_yr_wk = as.integer(wm_yr_wk),
    sell_price = as.double(sell_price)
  ) %>%
  left_join( items[,c("item_id" , "item_name" )], by = c("item_name" )) %>%
  left_join(stores[,c("store_id", "store_name")], by = c("store_name")) %>%
  left_join( dates[,c("d"       , "wm_yr_wk"  )], by = c("wm_yr_wk"  )) %>%
  select(
    store_id,
    item_id,
    d,
    sell_price
  ) %>%
  arrange() %>%
  as.data.table()

setkey(sell_prices_min, "store_id", "item_id", "d")

sell_prices_full_skeleton =
  dates[,c("d")] %>%
  crossing(item_id = items[["item_id"]]) %>%
  crossing(store_id = stores[["store_id"]]) %>%
  select(
    store_id,
    item_id,
    d
  ) %>%
  as.data.table()

setkey(sell_prices_full_skeleton, "store_id", "item_id", "d")

sell_prices_full =
  merge(
    sell_prices_full_skeleton,
    sell_prices_min,
    by = c("store_id", "item_id", "d"),
    all.x = TRUE
  )

sample_n(sell_prices_full, 1000) %>% View()

sell_prices_full %>% lazy_dt() %>%
  filter(item_id == 4, store_id == 6) %>%
  as.data.table() %>% View()

set.seed(2542589)
ck_stores = sample(stores[["store_id"]], 4)
ck_items = sample(items[["item_id"]], 3)

library(plotly)

sell_prices_full[
  item_id %in% ck_items
] %>%
  merge(stores[,c("store_id", "state_id", "store_id_state")], by = c("store_id"), all.x = TRUE) %>%
  mutate(
    item_id = paste0("item_id=", item_id),
    store_id = paste0("store_id=", store_id),
    state_id = paste0("state_id=", state_id),
    store_id_state = paste0("store_id_state=", store_id_state)
  ) %>%
  plotf(sell_price ~ d + store_id_state + state_id + item_id, geom=geom_line) %>%
  ggplotly()

# feature ideas:
# - current price compared to historic median price
# - price trend (l1 slope)
# - current price compared to historic max/min
# - ndays_since historic max/min
# - item is "on special": current price is _much_ lower than "typical" price
# - compare price of item at _this_ store to other stores in the same state
# - compare price of item at _this_ store to _all_ other stores
# - compare price of item at _this_ store to price of other items in the same
#     {dept,cat} at this store {,and over time}
# - ndays price has been the same
