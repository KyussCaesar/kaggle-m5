#!/usr/bin/env python3
import sys
import json

from re import sub
from glob import glob
from itertools import chain
from subprocess import run

navs = []

deps = []

for file in sorted(chain(glob("*.Rmd"), glob("*.md"))):
  deps.append(file)
  
  # RMarkdown puts broken links if there are spaces in the filenames...
  txt = sub(r"\.R?md", "", file)
  hrf = sub(r" ", "-", txt) + ".html"
  
  navs.append({
    "text": txt,
    "href": hrf,
  })

# close_fds defaults to True, causes broken --jobserver-auth for redo
run(["redo-ifchange", *deps], check=True, close_fds=False)

site = {
  "name": "kyuss-caesar/kaggle-m5",
  "output_dir": ".",
  "navbar": {
    "title": "kyuss-caesar/kaggle-m5",
    "left": navs
  },
  "output": {
    "html_document": {
      "toc": True
    }
  }
}

with open(sys.argv[3], "w") as f:
  json.dump(site, f, indent=2)

with open(sys.argv[3], "r") as f:
  run("redo-stamp", stdin=f, check=True, close_fds=False)
