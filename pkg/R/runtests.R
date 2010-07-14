runtests <- function(pkg.dir=get("ScripTests.pkg.dir", envir=globalenv()),
                     pattern=".*", file=NULL,
                     full=FALSE, dir=TRUE,
                     clobber=FALSE, output.suffix=NULL, console=FALSE,
                     ...,
                     verbose=TRUE, envir=globalenv(), enclos=envir, subst=NULL,
                     path=mget("ScripTests.pkg.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]]) {
    if (!interactive() && basename(getwd())=="tests") {
        if (nargs() != 0)
            stop("runtests() is for interactive use - use runScripTests() in tests/runtests.R")
        # Looks like we're being called by R CMD check (because runtests()
        # instead of runScripTests() was put in tests/runtests.R.
        status <- runScripTests()
        return(status)
    }

    pkg.name <- read.pkg.name(path, pkg.dir)
    supplied.pkg.dir <- !missing(pkg.dir)
    supplied.path <- !missing(path)
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
    if (full) {
        check.dirs <- paste(c(pkg.name, pkg.dir), ".Rcheck", sep="")
        if (!any(file.exists(check.dirs)))
            stop("expected to find installed library ", pkg.name, " in ",
                 paste("'", check.dirs, "'", sep="", collapse=" or "),
                 " but neither of those directories exists")
        check.dirs <- check.dirs[file.exists(check.dirs)]
        if (!any(file.exists(file.path(check.dirs, pkg.name))))
            stop("expected to find installed library in ", file.path(check.dirs, pkg.name), " but that directory doesn't exist")
        check.dirs <- check.dirs[file.exists(file.path(check.dirs, pkg.name))]
        # if there's more than one, choose the one with the most recent modification time
        mt <- file.info(file.path(check.dirs, pkg.name))[,"mtime"]
        if (length(check.dirs) > 1)
            cat("* Using package in '", file.path(check.dirs, pkg.name), "' for running tests\n", sep="")
        check.dirs <- check.dirs[which.max(mt)]
        # This code relies on normalizePath converting to an absolute path
        r.libs.site.orig <- Sys.getenv("R_LIBS_SITE")[[1]]
        r.libs.site <- unique(sapply(c(strsplit(r.libs.site.orig, split=";")[[1]], check.dirs), normalizePath))
        Sys.setenv("R_LIBS_SITE", paste(r.libs.site, collapse=";"))
        on.exit(Sys.setenv("R_LIBS_SITE", r.libs.site.orig))
    }
    if (!is.null(dir)) {
        if (file.exists(dir)) {
            if (!clobber) {
                if (dir == paste(pkg.dir, ".tests", sep=""))
                    stop("dir for running tests '", dir, "' already exists - supply clobber=TRUE to overwrite")
                else
                    stop("dir for running tests '", dir, "' already exists and is non-standard - remove it manually to continue")
            } else if (dir == paste(pkg.dir, ".tests", sep="")) {
                if (verbose)
                    cat("* Removing old tests directory ", dir, "\n", sep="")
                unlink(dir, recursive=TRUE)
            } else {
                stop("can only clobber test dir when it has the form of an automatically created one (i.e., like '",
                     paste(pkg.dir, ".tests", sep=""), "') - remove '", dir, "' manually to continue")
            }
        } else {
            if (!dir.create(dir, recursive=TRUE))
                stop("failed to create directory: ", dir)
        }
        if (verbose)
            cat("* Copying ", test.dir, " to ", dir, "\n", sep="")
        dir.create(dir)
        for (f in list.files(test.dir))
            file.copy(file.path(test.dir, f), dir, recursive=TRUE)
        existing.files <- list.files()
        if (verbose)
            cat("* Setting working directory to ", dir, "\n", sep="")
        setwd(dir)
        on.exit(setwd(cwd))
    }
    if (!full) {
        if (!is.null(output.suffix) && length(output.suffix)!=1)
            stop("length(output.suffix)!=1")
        if (length(list(...)))
            warning("ignoring extra arguments when full=FALSE: ", paste(names(list(...)), collapse=", "))
    }

    if (supplied.pkg.dir)
        assign("ScripTests.pkg.dir", pkg.dir, envir=globalenv())
    if (supplied.path)
        assign("ScripTests.pkg.path", path, envir=globalenv())

    if (!full) {
        res <- runTestsHereFast(pattern=pattern, pkg.dir=pkg.dir, pkg.name=pkg.name, file=file, verbose=verbose, envir=envir, enclos=enclos, subst=subst, path=path)
        attr(res, "dir") <- dirname(names(res)[1])
        names(res) <- basename(names(res))
        if (console || (!is.null(output.suffix) && !(is.logical(output.suffix) && !output.suffix)))
            dumprout(res, output.suffix, console=console)
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
