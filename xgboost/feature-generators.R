# feature generators;
# e.g for a yoy feature, pass the series to mk_yoy

mk_cumsum = function(xs, a) cumsum(xs)

mk_lagon = function(xs, l) {
  lagxs = lag(xs, l, 0)
  (xs - lagxs) / (lagxs + 1)
}

mk_yoy = function(xs, a) mk_lagon(xs, 7*52*a)
mk_mom = function(xs, a) mk_lagon(xs, 7*4*a)
mk_wow = function(xs, a) mk_lagon(xs, 7*a)

get_trend = compiler::cmpfun(function(xw) {
  xw[is.na(xw)] <- 0
  trn = data.table(volume = xw, d = seq_along(xw))
  mdl = lm(volume ~ d, data = trn)

  mdl$coefficients[["d"]]
})

mk_trend = function(xs, a) {
  rollapply(xs, a, get_trend, fill = NA, align = "right")
}

mk_rollmeanr = function(xs, a) rollmean(xs, a, fill = NA, align = "right")
mk_rollmaxr  = function(xs, a) rollmax( xs, a, fill = NA, align = "right")
mk_rollsumr  = function(xs, a) rollsum( xs, a, fill = NA, align = "right")

mk_rollcountzerosr = function(xs, a) rollapply(xs, a, function(xw) sum(which(xw == 0)), fill = NA, align = "right")
mk_rollrmsr = function(xs, a) rollapply(xs, a, rms, fill = NA, align = "right")

# how far to forecast; for "forecasted" features
win_f = 28

# "seasonal" forecasts
# winsize sets the seasonality, nwins sets how many past windows to average
mk_seasonal_forecast = function(xs, nwins, winsize) {
  mat =
    rollapply(xs, nwins * winsize, function(xw) {
      mm = matrix(data = xw, nrow = nwins, ncol = winsize, byrow = TRUE)
      sf = apply(mm, 1, mean)
      rep(sf, ceiling(win_f / len(sf)))[1:win_f]
    }, fill = NA, align = "right")

  mat %>%
    t() %>%
    as.data.frame() %>%
    as.list() %>%
    unnamed()
}

mk_snaive = function(xs, a) mk_seasonal_forecast(xs, 1, a)
mk_swow = function(xs, a) mk_seasonal_forecast(xs, a, 7)
mk_smom = function(xs, a) mk_seasonal_forecast(xs, a, 7*4)
mk_syoy = function(xs, a) mk_seasonal_forecast(xs, a, 7*52)

# ARIMA forecast on the last a days
mk_arimaw = function(xs, a) {
  mat =
    rollapply(xs, a, function(xw) {
      mdl = auto.arima(xw, lambda = "auto", biasadj = TRUE)

      fcs = forecast(mdl, h = win_f, level = 85)
      fcs = clamp(as.double(fcs[["mean"]]), 0, NULL)
      fcs[is.nan(fcs)] <- 0 # remove NaNs created by back-transform (biasadj)

      # TODO: find out how to return more than 1 series
      # might be able to re-use the list-column trick, just return multiple
      # columns in the nested list.
      # arima_ci85_lo = clamp(as.double(fcs$lower), 0, NULL)
      # arima_ci85_hi = clamp(as.double(fcs$upper), 0, NULL)
      fcs
    }, fill = NA, align = "right")

  mat %>%
    t() %>%
    as.data.frame() %>%
    as.list() %>%
    unnamed()
}
