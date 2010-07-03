
pkg.path <- function(path, pkg.dir) {
    if ((i <- regexpr("$PKG", path, fixed=TRUE)) >= 1) {
        return(gsub("$PKG", pkg.dir, path, fixed=TRUE))
    } else {
        return(file.path(path, pkg.dir))
    }
}
