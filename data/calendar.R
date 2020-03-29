ndays_in_mnths =
  tibble(
    year = 2011:2016
  ) %>%
  crossing(
    mnth = 1:12
  ) %>%
  mutate(
    d1 = paste(year, sprintf("%02.0f", mnth), "01", sep = "-"),
    d2 = lead(d1, default = paste0(max(year) + 1, "-01-01")),
    d3 = as.character(as.Date(d2) - as.difftime(1, units = "days"))
  ) %>%
  transmute(
    year,
    mnth,
    ndays_in_mnth = as.integer(sub("[0-9]{4}-[0-9]{2}-", "", d3))
  )

ndays_in_years =
  ndays_in_mnths %>%
  group_by(year) %>%
  summarise(ndays_in_year = sum(ndays_in_mnth))

mk_yday = function(year, mnth, mday) {
  d1 = paste(year, "01", "01", sep = "-")
  d2 = paste(year, sprintf("%02.0f", mnth), sprintf("%02.0f", mday), sep = "-")

  as.integer(as.Date(d2) - as.Date(d1), units = "days") + 1
}

dates =
  df %>%
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

setkey(dates, "d")
setindex(dates, "wm_yr_wk")

# TODO: events features:
# - set{key,index} on generated tables
# - days {to next,since last,to nearest (max of prev. 2)} {event,event type}

# df %>%
#   count(event_name_1, event_type_1, event_name_2, event_type_2) %>%
#   as.data.table() %>% View()

df_out =
  list(
    ndays_in_mnths = ndays_in_mnths,
    ndays_in_years = ndays_in_years,
    dates = dates
  )
