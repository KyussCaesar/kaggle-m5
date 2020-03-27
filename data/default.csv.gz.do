redo-ifchange "$2.csv"
gzip --keep --stdout "$2.csv" >"$3"

# _don't_ re-run _my dependencies_ if my output is the same
cat "$3" | sha256sum | redo-stamp
