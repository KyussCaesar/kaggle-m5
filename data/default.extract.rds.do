WHAT=$(echo "$1" | cut -f1 -d'.')
FROM=$(echo "$1" | cut -f2 -d'.').rds

redo-ifchange "$FROM"

R --slave <<EOF
dd = readRDS("$FROM")
stopifnot("$WHAT" %in% names(dd))
saveRDS(dd[["$WHAT"]], "$3")
EOF

redo-stamp <$3
