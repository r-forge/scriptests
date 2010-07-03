runtests <- function(pkg.dir=get("working.package.dir", envir=globalenv()),
                     pattern=".*", file=NULL,
                     full=FALSE, dir=paste(pkg.dir, ".tests", sep=""),
                     clobber=FALSE, output.suffix=NULL,
                     ...,
                     progress=TRUE, envir=globalenv(), enclos=envir, subst=NULL,
                     path=mget("working.package.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]]) {
    pkg.name <- read.pkg.name(path, pkg.dir)
    if (!missing(pkg.dir))
        assign("working.package.dir", pkg.dir, envir=globalenv())
    if (!missing(path))
        assign("working.package.path", path, envir=globalenv())
    if (!is.null(file) && pattern!=".*")
        stop("cannot supply both 'file' and 'pattern'")
    if (is.null(subst)) {
        # remote text "package:::" if "package" is not attached
        if (!is.element(paste("package:", pkg.name, sep=""), search())) {
            subst <- rep("", 2)
            names(subst) <- c(paste("\\b", pkg.name, ":::?", sep=""), paste("\\blibrary\\( *['\"]?", pkg.name, "['\"]? *\\)", sep=""))
            cat("* Package '", pkg.name, "' is not loaded as a package; will remove ", paste('"', names(subst), '"', collapse=", ", sep=""), " in tests\n", sep="")
        }
    } else if (is.logical(subst) && !subst) {
        # Don't do any substitution
        subst <- NULL
    } else if (!is.character(subst)) {
        stop("subst must be NULL, F, or a character vector")
    }
    if (!full) {
        if (length(list(...)))
            warning("ignoring extra arguments when full=FALSE: ", paste(names(list(...)), collapse=", "))
        res <- runTestsHereFast(pattern=pattern, pkg.dir=pkg.dir, pkg.name=pkg.name, file=file, progress=progress, envir=envir, enclos=enclos, subst=subst, path=path)
        if (!is.null(output.suffix) && !(is.logical(output.suffix) && !output.suffix)) {
            if (length(output.suffix)!=1)
                stop("length(output.suffix)!=1")
            dumprout(res, output.suffix)
        }
        return(invisible(res))
    } else {
        if (!is.null(output.suffix))
            stop("can only supply output.suffix= argument when full==FALSE")
        if (!is.null(file))
            stop("can only supply file= argument when full==FALSE")
        cwd <- getwd()
        test.dir <- file.path(pkg.path(path, pkg.dir), "tests")
        if (!file.exists(test.dir))
            stop("test directory ", test.dir, " does not exist")
        if (file.exists(dir)) {
            if (!clobber) {
                stop("dir for running tests ", dir, " already exists - supply clobber=TRUE to overwrite")
            } else if (dir == paste(pkg.dir, ".tests", sep="")) {
                if (progress)
                    cat("* Removing old tests directory ", dir, "\n", sep="")
                unlink(dir, recursive=TRUE)
            } else {
                stop("can only clobber test dir when it has the form of an automatically created one (",
                     paste(pkg.dir, ".tests", sep=""), ")")
            }
        }
        on.exit(setwd(cwd))
        if (progress)
            cat("* Copying ", test.dir, " to ", dir, "\n", sep="")
        dir.create(dir)
        for (f in list.files(test.dir))
            file.copy(file.path(test.dir, f), dir, recursive=TRUE)
        if (progress)
            cat("* Setting working directory to ", dir, "\n", sep="")
        setwd(dir)
        existing.files <- list.files()
        status <- runScripTests(..., quit=FALSE, subst=subst)
        new.files <- setdiff(list.files(), existing.files)
        if (FALSE && length(new.files)) {
            cat("* Removing ", length(new.files), " new files: ", paste(new.files, collapse=", "), "\n", sep="")
            file.remove(new.files)
        }
        return(status)
    }
}
