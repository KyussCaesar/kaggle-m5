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
  stem = sub(r"\.R?md", "", file)
  txt = sub(r"-", " ", stem)
  hrf = stem + ".html"

  navs.append({
    "text": txt,
    "href": hrf,
  })

# close_fds defaults to True, causes broken --jobserver-auth for redo
run(["redo-ifchange", *deps], check=True, close_fds=False)

fig_scale = 2.5

site = {
  "name": "kyuss-caesar/kaggle-m5",
  "output_dir": ".",
  "navbar": {
    "title": "kyuss-caesar/kaggle-m5",
    "left": navs
  },
  "output": {
    "html_document": {
      "toc": True,
      "toc_float": True,
      "theme": "cosmo",
      "highlight": "kate",
      "css": "styles.css",
      "fig_width": 4*fig_scale,
      "fig_height": 3*fig_scale,
      "fig_caption": True,
      "includes": {
        "in_header": "content/header.html"
      }
    }
  }
}

with open(sys.argv[3], "w") as f:
  json.dump(site, f, indent=2)

with open(sys.argv[3], "r") as f:
  run("redo-stamp", stdin=f, check=True, close_fds=False)
