# Generate ARIMA forecasts of sales volume for each training date

reload("sales")

pb_arima <- NULL

arima_backwindow = max(J) + 7

df_out =
  sales %>%
  lazy_dt() %>%
  filter(d >= min(N) - arima_backwindow) %>%
  select(target_id, d, volume) %>%
  as_tibble() %>%
  (function(x) {
    pb_arima <<- mkbar("create ARIMA forecasts", nrow(x))
    x
  }) %>%
  nest(data = c(d, volume)) %>%
  mutate(data = map(data, compiler::cmpfun(function(x) {
    x2 =
      x %>%
      arrange(d) %>%
      as.data.table()

    these_ds = x2[,d]
    res = vector(mode = "list", length = len(these_ds))

    for (dx in seq_along(these_ds)) {
      di = these_ds[dx]
      trn = x2[d <= di & d > di - arima_backwindow,]

      if (nrow(trn) > 5) {
        mdl =
          auto.arima(
            trn[,volume],
            lambda = "auto",
            biasadj = TRUE
          )

        fcs = forecast(mdl, h = max(J), level = 85)
        arima_forecast = clamp(as.double(fcs[["mean"]]), 0, NULL)
        arima_forecast[is.nan(arima_forecast)] <- 0 # remove NaNs created by back-transform (biasadj)
        arima_ci85_lo = clamp(as.double(fcs$lower), 0, NULL)
        arima_ci85_hi = clamp(as.double(fcs$upper), 0, NULL)

      } else {
        arima_forecast = trn[d == di, volume]
        arima_ci85_lo = NA
        arima_ci85_hi = NA
      }

      res[[dx]] =
        tibble(
          n = di,
          target_d = di + J,
          arima_forecast = arima_forecast,
          arima_ci85_lo = arima_ci85_lo,
          arima_ci85_hi = arima_ci85_hi
        )

      pb$tick()
    }

    do.call(rbind, res)
  }))) %>%
  unnest(cols = "data")
