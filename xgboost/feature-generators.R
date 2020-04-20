mk_cumsum = function(xs, a) cumsum(xs)

mk_lagon = function(xs, l) {
  lagxs = lag(xs, l, 0)
  (xs - lagxs) / (lagxs + 1)
}

# TODO: supplement these with "seasonal naiive" forecasts
# (will be done with target-date features)
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
  rollapply(xs, a, get_trend, fill = 0, align = "right")
}

mk_rollmeanr = function(xs, a) rollmean(xs, a, fill = 0, align = "right")
mk_rollmaxr  = function(xs, a) rollmax( xs, a, fill = 0, align = "right")
mk_rollsumr  = function(xs, a) rollsum( xs, a, fill = 0, align = "right")

mk_rollcountzerosr = function(xs, a) rollapply(xs, a, function(xw) sum(which(xw == 0)), fill = 0, align = "right")

