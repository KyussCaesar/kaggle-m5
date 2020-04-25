argv = commandArgs(TRUE)
agg_var = argv[1]

print(agg_var)

chunks = list.files(agg_var, pattern = "*-collected", full.names = TRUE)
feature = mapreduce(chunks, qload, cbind)
qsave(feature, paste0(agg_var, "-collected"))
