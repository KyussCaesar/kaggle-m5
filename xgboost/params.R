
# the index that we are building
#I = argv[1]
I = 3564

# horizons
J = 1:28

# heirarchy levels
L = 1:12

# number of training days
n_train = 6

# cutoff dates; i.e last dates in training sets
# <1855: training data
#  1884: "validation" set for training
#  1913: "validation" set from competition
#  1941: "evaluation" set from competition
# we don't use _all_ the training data cause it's too big for my computer :(
N = c((1855 - n_train):1855, 1884, 1913, 1941)
debugit(len(N))

# when validation set is made available, use this one
#N = c((1884 - n_train):1884, 1913, 1941)

reload("sales")
t_target = sales[target_id == I,unique(target_id)]
t_item   = sales[target_id == I,unique(item_id)  ]
t_store  = sales[target_id == I,unique(store_id) ]
t_state  = sales[target_id == I,unique(state_id) ]
t_cat    = sales[target_id == I,unique(cat_id)   ]
t_dept   = sales[target_id == I,unique(dept_id)  ]

# TODO: extract this into a converter under `data/src`
# windows are 1 week, 2 weeks, 1 mth, 3 mth, 6 mth
# generate features (join against d)
# - volume
# - trnovr
# - {volume,trnovr}_cumsum
# - {volume,trnovr}_{yoy_{1,2},mom_{1,2,3,6,12},wow_{1,2,4}}
# - {tgt,itm,str,stt,cat,dpt}_{volume,trnovr}_{cumsum,yoy_{1,2},mom_{1,2,3,6,12},wow_{1,2,4},{trend,roll{mean,max,sum}r}_{7,14,28,84,182}}
#
# generate features (join against target d)
# - volume_arima_{forecast,lower85,upper85}_{7,14,28,84,182}
# - volume_trend_forecast_{7,14,28,84,182}

s_tgt =
  sales[
    target_id == t_target
  ][
    order(d),
    .(
      tgt_volume = sum(volume),
      tgt_trnovr = sum(trnovr)
    ),
    .(d, target_id)
  ][
    order(d),
    .(
      cumvol_tgt = cumsum(volume_tgt),
      cumtrn_tgt = cumsum(trnovr_tgt)
    )
  ]

s_itm = sales[item_id   == t_item  ][order(d), .(volume_itm = sum(volume)), .(d, item_id  )]
s_str = sales[store_id  == t_store ][order(d), .(volume_str = sum(volume)), .(d, store_id )]
s_stt = sales[state_id  == t_state ][order(d), .(volume_stt = sum(volume)), .(d, state_id )]
s_cat = sales[cat_id    == t_cat   ][order(d), .(volume_cat = sum(volume)), .(d, cat_id   )]
s_dpt = sales[dept_id   == t_dept  ][order(d), .(volume_dpt = sum(volume)), .(d, dept_id  )]

setkey(s_tgt, "d", "target_id")
setkey(s_itm, "d", "item_id")
setkey(s_str, "d", "store_id")
setkey(s_stt, "d", "state_id")
setkey(s_cat, "d", "cat_id")
setkey(s_dpt, "d", "dept_id")

dm_nrow = len(I) * len(N) * len(J)
loginfo("Generate DM skeleton with %i rows", dm_nrow)

dm =
  list(
    i = I,
    n = N,
    j = J
  ) %>%
  cross_df() %>%
  as.data.table()

setkey(dm, "i")
setindex(dm, "n")
setindex(dm, "j")
setindex(dm, "i", "n")

# feature: extra identifiers for the target
dm =
  merge(
    dm, unique(sales[,.(id = target_id, item_id, store_id, cat_id, dept_id, state_id)]),
    by.x = "i", by.y = "id", all.x = TRUE
  )

# feature: target_d
dm[,target_d := n + j]

# add the target
dm = merge(dm, sales[,.(target_id, d, volume)], by.x = c("i", "target_d"), by.y = c("target_id", "d"), all.x = TRUE)

# feature: launch date (first date with non-zero sales for the target)
# Note: use this to drop rows that represent forecasts being made before launch.
# This is because the error is scaled against the 1-step naive forecast error on the training data
# which is undefined if there is no history for the series.
# Drop these rows before generating other features; performance optimisation.
reload("launch_dates")
dm = merge(dm, launch_dates, by.x = "i", by.y = "target_id", all.x = TRUE)[n > launch_date_i + 1]

# feature: days_since_launch
dm[,days_since_launch := target_d - launch_date_i]

# feature: date info
reload("dates")
dm = merge(
  dm, dates[,.(d, year, mnth, wday, nth_wday_in_mnth, year_pos, mnth_pos)],
  by.x = "target_d", by.y = "d", all.x = TRUE
)

# feature: last known sales
dm = merge(dm, sales[, .(target_id, d, volume_1 = volume)], by.x = c("i", "n"), by.y = c("target_id", "d"), all.x = TRUE)

# feature: cumsum of sales
sales[,.(target_id, d, volume_cumsum = cumsum(volume))]

# feature: arima forecasts
arima_backwindow = max(J) + 7
