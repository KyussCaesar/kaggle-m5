redo_load(ndays_in_mnths = "ndays_in_mnths.qs")

df_out =
  ndays_in_mnths %>%
  group_by(year) %>%
  summarise(ndays_in_year = sum(ndays_in_mnth))

