# todo: kill this script, just have `csv2rds` do everything

LOADER=csv2rds.R
INPUTFILE="$2.csv.gz"
CONVERTER="$2.R"

if [ -f "$2.deps" ]
then
  DEPS=$(cat "$2.deps") # | tr '\n' ' ')
else
  DEPS=
fi
    
redo-ifchange "$LOADER" "$INPUTFILE" "$CONVERTER" $DEPS ../utils.R

exec >&2

Rscript --quiet "$LOADER" "$INPUTFILE" "$CONVERTER" "$3"

redo-stamp <$3
