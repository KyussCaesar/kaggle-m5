#!/usr/bin/env Rscript
# Convert gzipped-csv into data.table, serialised as RDS.

# ensure logs go to stderr
sink(stderr())

# process args from redo
argv = commandArgs(TRUE)
inputfile = sprintf("%s.csv.gz", argv[2])
converter = sprintf("%s.R", argv[2])
dst = argv[3]

# debug/testing values
if (FALSE) {
  basen = "sell_prices"
  inputfile = sprintf("%s.csv.gz", basen)
  converter = sprintf("%s.R", basen)
}

redo(inputfile, converter)

.nologs = TRUE
if (.nologs) {
  loginfo = function(...) {invisible(NULL)}
} else {
  # in case we re-run, set it back
  loginfo = logging::loginfo
}

# input, read as data.table
# don't touch _anything_, just read all as character
# the converter for the specified target will perform the conversion
loginfo("read %s", inputfile)
dur <- system.time({
  df_src =
    fread(
      inputfile,
      stringsAsFactors = FALSE,
      verbose = FALSE,
      showProgress = TRUE,
      colClasses = "character",
      data.table = TRUE,
      encoding = "UTF-8"
    )
})

loginfo("done reading %s, took %0.2f", inputfile, dur[3])

# input, but as a "lazy" data.table; for dtplyr
df = lazy_dt(df_src)

# output, will be serialised to RDS
df_out = NULL

# use the converter for the specified target to perform the conversion
loginfo("begin conversion for %s", inputfile)
dur <- system.time({
  source(converter)

  # check: that the output variable was set
  if (is.null(df_out)) {
    stop("output has not been set!")
  }
})

loginfo("end conversion for %s", inputfile)

loginfo("conversion took %0.2f seconds", dur[3])

# dump output
dur <- system.time({
  saveRDS(df_out, dst)
})

loginfo("result saved to %s, took %0.2f seconds", dst, dur[3])

