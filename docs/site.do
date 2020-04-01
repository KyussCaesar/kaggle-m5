redo-ifchange _site.yml

find . \
  -type f \
  -name '*.Rmd' -or -name '*.md' \
  -exec redo-ifchange {} +

R --slave >&2 <<EOF
rmarkdown::render_site()
EOF

