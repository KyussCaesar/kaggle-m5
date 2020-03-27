debugit = function(x) {
  var = deparse(substitute(x))
  val = eval(x)
  loginfo(paste(var, "=", val))
  invisible(val)
}
