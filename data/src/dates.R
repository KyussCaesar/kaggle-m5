redo_load(
  df = "calendar.csv.qs",
  ndays_in_years = "ndays_in_years.qs",
  ndays_in_mnths = "ndays_in_mnths.qs"
)

mk_yday = function(year, mnth, mday) {
  d1 = paste(year, "01", "01", sep = "-")
  d2 = paste(year, sprintf("%02.0f", mnth), sprintf("%02.0f", mday), sep = "-")

  as.integer(as.Date(d2) - as.Date(d1), units = "days") + 1
}

df_out =
  df %>%
  lazy_dt() %>%
  transmute(
    d = sub("d_", "", d),
    wm_yr_wk,
    year,
    mnth = month,
    mday = sub("[0-9]{4}-[0-9]{2}-", "", date),
    wday,
    snap_CA,
    snap_TX,
    snap_WI
  ) %>%
  mutate_all(as.integer) %>%
  mutate(yday = mk_yday(year, mnth, mday)) %>%
  left_join(ndays_in_mnths, by = c("year", "mnth")) %>%
  left_join(ndays_in_years, by = c("year")) %>%
  group_by(year, mnth, wday) %>%
  mutate(
    nth_wday_in_mnth = 1:n(),
    mnth_pos = mday / ndays_in_mnth,
    year_pos = yday / ndays_in_year
  ) %>%
  ungroup() %>%
  select(
    d,
    wm_yr_wk,
    year,
    mnth,
    mday,
    ndays_in_year,
    ndays_in_mnth,
    yday,
    wday,
    nth_wday_in_mnth,
    year_pos,
    mnth_pos,
    snap_CA,
    snap_TX,
    snap_WI
  ) %>%
  arrange(d) %>%
  as.data.table()

setkey(df_out, "d")
setindex(df_out, "wm_yr_wk")

# TODO: events features:
# one-hot-encode "is $event"?
# - days {to next,since last,to nearest (max of prev. 2)} {event,event type}
