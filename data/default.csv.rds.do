#!/usr/bin/env Rscript
# reads CSV and dumps straight back to RDS
# this is so you can pick up the raw files using `redo_load`

# ensure logs go to stderr
sink(stderr())

argv = commandArgs(TRUE)

inputfile = sprintf("%s.csv", argv[2])
redo(inputfile)

# note: read _everything_ as character
# dunno what the data will be used for so leave the rest
# of the parsing up to consumers of this table
saveRDS(
  fread(
    inputfile,
    stringsAsFactors = FALSE,
    verbose = FALSE,
    showProgress = TRUE,
    colClasses = "character",
    data.table = TRUE,
    encoding = "UTF-8"
  ),
  argv[3]
)

# stamp output just in case
redo_stamp(argv[3])
