#!/usr/bin/env python3
import sys
import json

from re import sub
from glob import glob
from itertools import chain

navs = []

for file in sorted(chain(glob("*.Rmd"), glob("*.md"))):
  navs.append({
    "text": file,
    "href": sub(r"\.R?md", ".html", file)
  })

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
  json.dump(site, f)
