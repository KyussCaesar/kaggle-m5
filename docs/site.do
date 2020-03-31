redo-ifchange _site.yml

find . \
  -type f \
  -name '*.Rmd' -or -name '*.md' \
  -exec python -c 'from shlex import quote; print(quote("{}"))' \; \
  | xargs redo-ifchange

R --slave >&2 <<EOF
rmarkdown::render_site()
EOF

