redo_load(
  df = "sell_prices.csv.rds",
  stores = "stores.rds",
  items  = "items.rds",
  dates  = "dates.rds"
)

prices_min =
  df %>%
  lazy_dt() %>%
  transmute(
    store_name = store_id,
    item_name = item_id,
    wm_yr_wk = as.integer(wm_yr_wk),
    price = as.double(sell_price)
  ) %>%
  left_join( items[,c("item_id" , "item_name" )], by = c("item_name" )) %>%
  left_join(stores[,c("store_id", "store_name")], by = c("store_name")) %>%
  left_join( dates[,c("d"       , "wm_yr_wk"  )], by = c("wm_yr_wk"  )) %>%
  select(
    store_id,
    item_id,
    d,
    price
  ) %>%
  arrange() %>%
  as.data.table()

setkey(prices_min, "store_id", "item_id", "d")

prices_skeleton =
  dates[,c("d")] %>%
  crossing(item_id = items[["item_id"]]) %>%
  crossing(store_id = stores[["store_id"]]) %>%
  select(
    store_id,
    item_id,
    d
  ) %>%
  as.data.table()

setkey(prices_skeleton, "store_id", "item_id", "d")

df_out =
  merge(
    prices_skeleton,
    prices_min,
    by = c("store_id", "item_id", "d"),
    all.x = TRUE
  )

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
