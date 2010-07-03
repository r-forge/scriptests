runtests <- function(pkg=get("working.package", envir=globalenv()),
                     pattern=".*", file=NULL,
                     full=FALSE, dir=paste(pkg, ".tests", sep=""),
                     clobber=FALSE, output=NULL,
                     ...,
                     progress=TRUE, envir=globalenv(), enclos=envir, subst=NULL,
                     path=mget("working.package.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]]) {
    if (!missing(pkg))
        assign("working.package", pkg, envir=globalenv())
    if (!missing(path))
        assign("working.package.path", path, envir=globalenv())
    if (!is.null(file) && pattern!=".*")
        stop("cannot supply both 'file' and 'pattern'")
    if (is.null(subst)) {
        # remote text "package:::" if "package" is not attached
        if (!is.element(paste("package:", pkg, sep=""), search())) {
            subst <- rep("", 2)
            names(subst) <- c(paste("\\b", pkg, ":::?", sep=""), paste("\\blibrary\\( *['\"]?", pkg, "['\"]? *\\)", sep=""))
            cat("* Package '", pkg, "' is not loaded as a package; will remove ", paste('"', names(subst), '"', collapse=", ", sep=""), " in tests\n", sep="")
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
        res <- runTestsHereFast(pattern=pattern, pkg=pkg, file=file, progress=progress, envir=envir, enclos=enclos, subst=subst, path=path)
        if (!is.null(output) && !(is.logical(output) && !output)) {
            if (length(output)!=1)
                stop("length(output)!=1")
            dumprout(res, output)
        }
        return(invisible(res))
    } else {
        if (!is.null(output))
            stop("can only supply output= argument when full==FALSE")
        if (!is.null(file))
            stop("can only supply file= argument when full==FALSE")
        cwd <- getwd()
        test.dir <- file.path(pkg.path(path, pkg), "tests")
        if (!file.exists(test.dir))
            stop("test directory ", test.dir, " does not exist")
        if (file.exists(dir)) {
            if (!clobber) {
                stop("dir for running tests ", dir, " already exists - supply clobber=TRUE to overwrite")
            } else if (dir == paste(pkg, ".tests", sep="")) {
                if (progress)
                    cat("* Removing old tests directory ", dir, "\n", sep="")
                unlink(dir, recursive=TRUE)
            } else {
                stop("can only clobber test dir when it has the form of an automatically created one (",
                     paste(pkg, ".tests", sep=""), ")")
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

runTestsHereFast <- function(pattern=".*",
                             pkg=get("working.package", envir=globalenv()),
                             file=NULL,
                             progress=TRUE, envir=globalenv(), enclos=envir, subst=NULL,
                             test.suffix=".Rt",
                             path=mget("working.package.path", envir=globalenv(), ifnotfound=list(getwd()))) {
    # This does the similar work as runScripTests()/.runPackageTests(),
    # with these differences:
    #
    #   (1) tests are run in the current directory rather than creating
    #       a copy of the package 'tests' directory and doing setwd() on it
    #   (2) all test code is run in this R session (runScripTests() runs
    #       each file in a different R session)
    #   (3) doesn't read the CONFIG file
    #   (4) use of ScripTests initialize/diff/finalize is hardwired in here
    #   (5) output is captured using evalCapture() instead of reading it
    #       from a transcript
    if (!is.null(file)) {
        files <- file.path(pkg.path(path, pkg), "tests", file)
        if (!all(i <- file.exists(files))) {
            warning("ignoring non-existant files ", paste(files[!i], collapse=", "))
            files <- files[i]
        }
    } else {
        if (nchar(test.suffix))
            test.suffix <- gsub("^\\.", "\\.", test.suffix)
        if (regexpr(paste(test.suffix, "$", sep=""), pattern, ignore.case=T) < 1)
            pattern <- paste(pattern, ".*", test.suffix, "$", sep="")
        files <- list.files(file.path(pkg.path(path, pkg), "tests"), pattern=pattern, full=TRUE, ignore.case=TRUE)
        if (length(files)==0)
            stop("no files matched the pattern '", pattern, "' in ", file.path(pkg, "tests"))
    }
    allres <- list()
    for (file in files) {
        if (progress)
            cat("* Running tests in", file)
        tests <- parseTranscriptFile(file, subst=subst)
        if (progress)
            cat(" (read", length(tests), "chunks)\n")
        res <- lapply(seq(along=tests), function(i) {
            test <- tests[[i]]
            if (is(test$expr, "try-error"))
                actual <- as.character(test$expr)
            else
                actual <- evalCapture(test$expr, envir, enclos)
            res <- compareSingleTest(test$input, test$control, test$output, actual,
                                     i, file, progress=progress)
            res$comment <- test$comment
            res$transcript <- c(test$input, test$control, actual)
            res$target <- c(test$output)
            res
        })
        class(res) <- "RtTestSetResults"
        attr(res, "testname") <- file
        if (progress) {
            cat("\n")
            print(summary(res))
        }
        allres[[file]] <- res
    }
    class(allres) <- "RtTestSetResultsList"
    if (length(allres)>1)
        print(summary(allres))
    invisible(allres)
}

evalCapture <- function(expr, envir=globalenv(), enclos=envir) {
    ## Try to return the output that is returned at an interactive prompt
    ## when given the contents of 'text', including error messages
    ## (only the value from the last expression in text is printed)
    ## A zero-length character vector is returned when the result is invisible.
    ## Constructed this definition of eval.with.vis() based on code in source()
    if (is.null(expr))
        return(character(0))
    withWarnings <- function(expr) {
        ## Note that capturing warnings in the way done here bypasses the standard
        ## warning handling mechanisms, so options(warn=) makes no difference to
        ## how the code behaves here.  Rather than try to reproduce all the behaviors,
        ## settle for simulating options(warn=1) (i.e., print warnings immediately)
        ## The standard warnings handling code is in
        ##   static void vwarningcall_dflt(SEXP call, const char *format, va_list ap)
        ## in src/main/errors.c
        wHandler <- function(w) {
            ## Try to format the message in the same way as is done
            ## for standard warning messages. (see vwarningcall_dflt() in src/main/errors.c)
            dcall <- deparse(w$call, nlines=1)
            if (sum(nchar(dcall)) + sum(nchar(w$message)) + 18 <= 75)
                cat("Warning in ", dcall, " : ", w$message, "\n", sep="")
            else
                cat("Warning in ", dcall, " :\n  ", w$message, "\n", sep="")
            invokeRestart("muffleWarning")
        }
        withCallingHandlers(expr, warning = wHandler)
    }
    ## Constructed this definition of eval.with.vis() based on code in source()
    ## and added the withWarnings() stuff to capture the warnings as well
    eval.with.vis <- function(expr, envir = envir, enclos = envir) {
        output <- capture.output(withWarnings(res <- .Internal(eval.with.vis(expr, envir, enclos))))
        res$output <- output
        res
    }
    res <- try(eval.with.vis(expr, envir, enclos), silent=TRUE)
    if (is(res, "try-error")) {
        res[1] <- gsub("Error in eval.with.vis\\(expr, envir, enclos\\) :[ \n\t]*", "Error: ", res[1], perl=TRUE)
        res <- gsub("\n$", "", res)
        return(as.character(res))
    }
    if (res$visible) {
        res2 <- try(capture.output(print(res$value)), silent=TRUE)
        return(c(res$output, as.character(res2)))
    } else {
        return(res$output)
    }
}

dumprout <- function(res = .Last.value, output = ".Rout.tmp", verbose = TRUE, clobber = identical(output, ".Rout.tmp")) {
    if (!is.element("RtTestSetResultsList", class(res)))
        stop("supplied argument is not a return value of runtests()")
    if (length(output)!=1)
        stop("length(output)!=1")
    if (is.character(output) && output!="") {
        if (substring(output, 1, 1)!=".")
            output <- paste(".", output, sep="")
    } else {
        output <- ".Rout.tmp"
    }
    for (i in seq(along=res)) {
        outfile <- basename(names(res)[i])
        if (outfile != "") {
            outfile <- gsub("\\.Rt", output, outfile)
            if (file.exists(outfile) && !clobber) {
                warning("file ", outfile, " exists already, specify clobber=TRUE to overwrite")
            } else {
                if (verbose)
                    cat("* Writing transcript of actual output to ", outfile, "\n", sep="")
                sink(outfile)
                on.exit(sink())
                print(res[[i]], transcript=TRUE)
                sink()
                on.exit()
            }
        }
    }
}

pkg.path <- function(path, pkg) {
    if ((i <- regexpr("$PKG", path, fixed=TRUE)) >= 1) {
        return(gsub("$PKG", pkg, path, fixed=TRUE))
    } else {
        return(file.path(path, pkg))
    }
}
