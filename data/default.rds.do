LOADER=csv2rds.R
INPUTFILE="$2.csv.gz"
CONVERTER="$2.R"

redo-ifchange "$LOADER" "$INPUTFILE" "$CONVERTER"

exec >&2

Rscript --quiet "$LOADER" "$INPUTFILE" "$CONVERTER" "$3"

cat "$3" | sha256sum | redo-stamp
