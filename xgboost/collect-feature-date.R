#!/usr/bin/env Rscript
argv = commandArgs(TRUE)

# each argv should be path to date-folder to aggregate
for (i in argv) {
  files2merge = list.files(i, full.names = TRUE)
  merged = mapreduce(files2merge, qload, rbind)

  file.remove(files2merge)
  qsave(merged, glue("{i}-merged"))
  file.remove(i)
}

