#!/usr/bin/env bash
set -euo pipefail
set -x

dbname="cv4lm.db"
sqlite3 -bail -echo $dbname <<EOF
DROP TABLE IF EXISTS cvlm;
CREATE TABLE cvlm (
  chunk_name TEXT
, cutoff INTEGER
, target_id INTEGER
, mdl_win INTEGER
, mdl_coef DOUBLE
, mdl_coef_stderr DOUBLE
, mdl_coef_statistic DOUBLE
, mdl_coef_pvalue DOUBLE
, horizon INTEGER
, volume INTEGER
, mdl_pred INTEGER
, mdl_err INTEGER
);

-- use write-ahead log; for multi-process access
PRAGMA journal_mode=WAL;
EOF

prep_stmt="INSERT INTO cvlm VALUES (:chunk_name, :cutoff, :target_id, :mdl_win, :mdl_coef, :mdl_coef_stderr, :mdl_coef_statistic, :mdl_coef_pvalue, :horizon, :volume, :mdl_pred, :mdl_err);"

find . -name 'lmcv-*.rds' \
  | head -n20 \
  | parallel -j12 --eta Rscript cv4lm-results.R "$dbname" "\"$prep_stmt\""

sqlite3 -bail -echo $dbname <<EOF
PRAGMA wal_checkpoint(TRUNCATE);
VACCUM;
PRAGMA optimize;
EOF

