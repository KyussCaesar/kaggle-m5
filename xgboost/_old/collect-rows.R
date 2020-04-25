argv = commandArgs(TRUE)
feature_name = argv[1]

print(feature_name)

mapreduce = compiler::cmpfun(function(xs, mapf, redf) {

  pb = mkbar(paste0("bind chunks for ", feature_name), len(xs))

  state = mapf(xs[[1]])
  pb$tick()

  if (len(xs) > 1) {
    for (i in 2:len(xs)) {
      state = redf(state, mapf(xs[[i]]))
      pb$tick()
    }
  }

  state
})

chunks = list.files(feature_name, pattern = "*.qs", full.names = TRUE)
feature = mapreduce(chunks, qload, rbind)
qsave(feature, paste0(feature_name, "-collected"))
