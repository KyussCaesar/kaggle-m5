redo-ifchange _site.yml

R --slave >&2 <<EOF
rmarkdown::render_site()
EOF

