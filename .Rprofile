
if (Sys.getenv("INSTALLING_PACKAGES") != "true") {
  # make the utils available everywhere
  source(here::here("utils.R"))

  # tell reticulate to use system python
  Sys.setenv(RETICULATE_PYTHON = "/usr/local/bin/python")

} else {
  message("skip loading utils during package install")
}

