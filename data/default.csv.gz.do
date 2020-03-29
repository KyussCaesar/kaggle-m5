redo-ifchange "$2.csv"
gzip --keep --stdout "$2.csv" >"$3"
redo-stamp <$3
