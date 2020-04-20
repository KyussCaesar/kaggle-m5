# generates lookup for number of days in each month

df_out =
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

