redo-always

R --slave >&2 <<EOF
rmarkdown::clean_site()
EOF

if [ -f _site.yml ]
then
  rm _site.yml
fi

