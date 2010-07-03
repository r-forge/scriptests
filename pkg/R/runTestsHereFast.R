runTestsHereFast <- function(pattern=".*",
                             pkg.dir=get("working.package.dir", envir=globalenv()),
                             pkg.name=NULL,
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
    if (is.null(pkg.name))
        pkg.name <- read.pkg.name(path, pkg.dir)
    if (!is.null(file)) {
        files <- file.path(pkg.path(path, pkg.dir), "tests", file)
        if (!all(i <- file.exists(files))) {
            warning("ignoring non-existant files ", paste(files[!i], collapse=", "))
            files <- files[i]
        }
    } else {
        if (nchar(test.suffix))
            test.suffix <- gsub("^\\.", "\\.", test.suffix)
        if (regexpr(paste(test.suffix, "$", sep=""), pattern, ignore.case=T) < 1)
            pattern <- paste(pattern, ".*", test.suffix, "$", sep="")
        files <- list.files(file.path(pkg.path(path, pkg.dir), "tests"), pattern=pattern, full=TRUE, ignore.case=TRUE)
        if (length(files)==0)
            stop("no files matched the pattern '", pattern, "' in ", file.path(pkg.dir, "tests"))
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
