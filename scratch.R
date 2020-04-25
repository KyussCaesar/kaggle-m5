hann = function(n, a0 = 25/46) {
  a0 - (1 - a0)*cos(0:(n-1) * ((2*pi) / (n - 1)) )
}

df =
  tibble(
    y1 = diffinv(runif(99, min = -0.5, max = 0.8)) + 1.3*cos(1*1:100),
    xs = seq_along(y1),
    z1 = abs(fft(y1)),
    hn = hann(len(y1), 0.503),
    z2 = z1 * hn
  ) %>%
  pivot_longer(-xs) %>%
  print()

ggplot(df, aes(x = xs, y = value)) +
  geom_line() +
  facet_wrap(~name, scales = "free", ncol = 1)

df =
  tibble(
    y1 = diffinv(rnorm(99)) + 1.2*cos(0.9*1:100),
    xs = seq_along(y1)
  )

win_b = 4
win_f = 28
mat =
  rollapply(df[["y1"]], width = win_b, function(xs) {
    rep(xs, ceiling(win_f / len(xs)))[1:win_f]
  }, fill = 0, align = "right", partial = TRUE)

df %>%
  mutate(
    sn_12 = mk_sn(y1, 12),
    j = list(1:28)
  ) %>%
  unnest(c(sn_12, j))

dd = df %>% as.data.table()
dd[, `:=`(j = list(1:28), sn_12 = mk_sn(y1, 12))]
dd %>%
  unnest(c(sn_12, j))

colnames(mat) <- 1:ncol(mat)
rownames(mat) <- 1:nrow(mat)
as_tibble(mat, rownames = "n") %>%
  pivot_longer(-n, names_to = "j", values_to = paste0("sn_", win_b))

df %>%
  pivot_longer(-xs) %>%
  ggplot(aes(x = xs, y = value)) +
  geom_line() +
  facet_wrap(~name, scales = "free", ncol = 1)
