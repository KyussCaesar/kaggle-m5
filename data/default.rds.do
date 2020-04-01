#!/usr/bin/env Rscript
# builds `foo.rds` from `foo.R`

# ensure logs go to stderr
sink(stderr())

# process args from redo
argv = commandArgs(TRUE)

converter = sprintf("%s.R", argv[2])
dst = argv[3]

redo(converter)

.nologs = TRUE
if (.nologs) {
  sink("/dev/null")
} else {
  # in case we re-run, set it back
  sink(stderr())
}

# output, will be serialised to RDS
# expect converter to set this var
df_out = NULL

srcargs = list(converter)
if (!.nologs) {
  srcargs[["echo"]] = TRUE
  srcargs[["keep.source"]] = TRUE
}

# use the converter for the specified target to perform the conversion
dur <- system.time({
  source(converter, echo = TRUE, keep.source = TRUE)
})

loginfo("call %s, took %0.2f seconds", converter, dur[3])

# check: that the output variable was set
if (is.null(df_out)) {
  stop("output has not been set!")
}

# dump output
dur <- system.time({
  saveRDS(df_out, dst)
})

loginfo("result saved to %s, took %0.2f seconds", dst, dur[3])
