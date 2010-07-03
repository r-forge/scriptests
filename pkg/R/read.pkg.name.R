read.pkg.name <- function(path, pkg.dir) {
    desc.path <- file.path(pkg.path(path, pkg.dir), "DESCRIPTION")
    # cat("  Reading", desc.path, "\n")
    if (file.exists(desc.path)) {
        pkg.name <- as.character(drop(read.dcf(desc.path, "Package")))
        if (is.na(pkg.name)) {
            warning("No 'Package' field in ", desc.path, "; using package name='", pkg.dir, "'")
            pkg.name <- pkg.dir
        }
    } else {
        warning("File ", desc.path, " doesn't exist; using package name='", pkg.dir, "'")
        pkg.name <- pkg.dir
    }
    return(pkg.name)
}
