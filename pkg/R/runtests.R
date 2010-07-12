runtests <- function(pkg.dir=get("ScripTests.pkg.dir", envir=globalenv()),
                     pattern=".*", file=NULL,
                     full=FALSE, dir=TRUE,
                     clobber=FALSE, output.suffix=NULL,
                     ...,
                     progress=TRUE, envir=globalenv(), enclos=envir, subst=NULL,
                     path=mget("ScripTests.pkg.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]]) {
    pkg.name <- read.pkg.name(path, pkg.dir)
    if (!missing(pkg.dir))
        assign("ScripTests.pkg.dir", pkg.dir, envir=globalenv())
    if (!missing(path))
        assign("ScripTests.pkg.path", path, envir=globalenv())
    if (!is.null(file) && pattern!=".*")
        stop("cannot supply both 'file' and 'pattern'")
    if (is.null(subst) && !full) {
        # remove text "package:::" if "package" is not attached
        if (!is.element(paste("package:", pkg.name, sep=""), search())) {
            subst <- rep("", 2)
            names(subst) <- c(paste("\\b", pkg.name, ":::?", sep=""), paste("\\blibrary\\( *['\"]?", pkg.name, "['\"]? *\\)", sep=""))
            cat("* Package '", pkg.name, "' is not loaded as a package; will remove ", paste('"', names(subst), '"', collapse=", ", sep=""), " in tests\n", sep="")
        }
    } else if (is.logical(subst) && !subst) {
        # Don't do any substitution
        subst <- NULL
    } else if (!is.character(subst) && !is.null(subst)) {
        stop("subst must be NULL, F, or a character vector")
    }
    if (full) {
        if (!is.null(output.suffix))
            stop("can only supply output.suffix= argument when full==FALSE")
        if (!is.null(file))
            stop("can only supply file= argument when full==FALSE")
    }
    # Change directory if needed
    cwd <- getwd()
    test.dir <- file.path(pkg.path(path, pkg.dir), "tests")
    if (!file.exists(test.dir))
        stop("test source directory ", test.dir, " does not exist")
    if (is.logical(dir))
        if (dir)
            if (full)
                dir <- paste(pkg.dir, ".Rcheck/tests", sep="")
            else
                dir <- paste(pkg.dir, ".tests", sep="")
        else
            dir <- NULL
    # Need this later, relative to the current path
    check.dir <- normalizePath(paste(pkg.dir, ".Rcheck", sep=""))
    if (full) {
        if (!file.exists(check.dir))
            stop("expected to find installed library ", pkg.name, " in ", check.dir, " but that directory doesn't exist")
        if (!file.exists(file.path(check.dir, pkg.name)))
            stop("expected to find installed library in ", file.path(check.dir, pkg.name), " but that directory doesn't exist")
        # This code relies on normalizePath converting to an absolute path
        r.libs.site.orig <- Sys.getenv("R_LIBS_SITE")[[1]]
        r.libs.site <- unique(sapply(c(strsplit(r.libs.site.orig, split=";")[[1]], check.dir), normalizePath))
        Sys.setenv("R_LIBS_SITE", paste(r.libs.site, collapse=";"))
        on.exit(Sys.setenv("R_LIBS_SITE", r.libs.site.orig))
    }
    if (!is.null(dir)) {
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
        } else {
            if (!dir.create(dir, recursive=TRUE))
                stop("failed to create directory: ", dir)
        }
        if (progress)
            cat("* Copying ", test.dir, " to ", dir, "\n", sep="")
        dir.create(dir)
        for (f in list.files(test.dir))
            file.copy(file.path(test.dir, f), dir, recursive=TRUE)
        existing.files <- list.files()
        if (progress)
            cat("* Setting working directory to ", dir, "\n", sep="")
        setwd(dir)
        on.exit(setwd(cwd))
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
        status <- runScripTests(..., quit=FALSE, subst=subst)
        new.files <- setdiff(list.files(), existing.files)
        if (FALSE && length(new.files)) {
            cat("* Removing ", length(new.files), " new files: ", paste(new.files, collapse=", "), "\n", sep="")
            file.remove(new.files)
        }
        return(status)
    }
}
