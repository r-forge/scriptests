## Modification of function .runPackageTests() from R-2.9.0/src/library/tools/R/testing.R
## used by R CMD check
## This is a private function in ScripTests, but it is written so that
## it could be a drop in replacement for .runPackageTests() in .../src/library/tools/R/testing.R

.runPackageTests <- function(use_gct = FALSE, run.preexisting.R.files=TRUE,
                             initializeFun=NULL, finalizeFun=NULL, diffFun=NULL,
                             debug=FALSE, stopOnError=TRUE, pattern=NULL, subst=NULL)
{

    runone <- function(f, diffFun=NULL, stopOnError=TRUE, debug=TRUE)
    {
        message("** Running ", sQuote(f), " in ", getwd())
        outfile <- paste(f, "out", sep = "")
        cmd <- paste(shQuote(file.path(R.home(), "bin", "R")),
                     "CMD BATCH --vanilla --no-timing",
                     shQuote(f), shQuote(outfile))
        if (.Platform$OS.type == "windows") {
            Sys.setenv(LANGUAGE="C")
            Sys.setenv(R_TESTS="startup.Rs")
        } else
            cmd <- paste("LANGUAGE=C", "R_TESTS=startup.Rs", cmd)
        res <- system(cmd)
        if (res) {
            message("   Failure running ", sQuote(f), ": returned code ", res)
            if (stopOnError) {
                file.rename(outfile, paste(outfile, "fail", sep="."))
                return(1L)
            }
        }
        savefile <- paste(outfile, "save", sep = "." )
        if (is.null(diffFun)) {
            if (file.exists(savefile)) {
                message("   Comparing ", sQuote(outfile), " to ",
                        sQuote(savefile), " ...", appendLF = FALSE)
                res <- Rdiff(outfile, savefile, TRUE)
                if (!res) message(" OK")
            }
        } else {
            args <- list(commandfile=f, outfile=outfile)
            if (file.exists(savefile))
                args <- c(args, list(savefile=savefile))
            for (i in seq(to=2, by=-1, len=max(0, length(diffFun)-1)))
                 diffFun[i+length(args)] <- diffFun[i]
            diffFun[seq(2,len=length(args))] <- args
            names(diffFun)[seq(2,len=length(args))] <- names(args)
            message("   Calling ", format(diffFun))
            res <- try(eval(diffFun))
            if (inherits(res, "try-error")) {
                message("   Error evaluting ", format(diffFun), ": ", as.character(res))
                return(1L)
            } else if (!is.numeric(res)) {
                message("   Error: ", format(diffFun), " returned non-numeric result:", as.character(res))
                return(1L)
            }
        }
        0L
    }
    if (run.preexisting.R.files) {
        if (Sys.getenv("TESTS_HAVE_RUN_R_FILES")=="") {
            Sys.setenv("TESTS_HAVE_RUN_R_FILES", "TRUE")
        } else {
            warning("refusing to run pre-existing .R and .Rin files: env var TESTS_HAVE_RUN_R_FILES is non-empty, so running these files might cause an infinite regression")
            run.preexisting.R.files <- FALSE
        }
    }
    preexisting.Rin.files <- dir(".", pattern="\\.Rin$")
    preexisting.R.files <- dir(".", pattern="\\.R$")

    file.copy(file.path(R.home("share"), "R", "tests-startup.R"), "startup.Rs")
    if (use_gct) cat("gctorture(TRUE)" , file = "startup.Rs", append = TRUE)
    nfail <- 0L ## allow for later running all tests even if some fail.

    needPkg <- character(0)
    if (file.exists("CONFIG")) {
        # need to make sure that the "tools" package is attached
        config <- read.dcf("CONFIG")[1L,]
        names(config) <- casefold(names(config), upper=FALSE)

        if (is.element("debug", names(config))) {
            debug <- try(eval(parse(text=config["debug"])[[1]])!=0)
            if (inherits(debug, "try-error")) {
                warning("could not interpret 'Debug' entry in CONFIG (\"", config["debug"], "\") as a logical value")
                debug <- TRUE
            } else if (length(debug)!=1 || is.na(debug)) {
                warning("could not interpret 'Debug' entry in CONFIG (\"", config["debug"], "\") did not evaluate to a single TRUE/FALSE value")
                debug <- TRUE
            }
            if (debug)
                message("   Setting debug=TRUE")
        }

        # a line like "Config: x:::y" in the CONFIG file will call x:::y to get config info
        if (is.element("config", names(config))) {
            configFun <- try(parse(text=config["config"])[[1]])
            configPkg <- character(0)
            if (!is.call(configFun)) {
                warning("could not parse 'Config' entry in CONFIG (\"", config["config"], "\") as a function call")
                return(1)
            } else if (!is.name(configFun[[1]]) && as.character(configFun[[1]][[1]]) == ":::") {
                configPkg <- as.character(configFun[[1]][[2]])
            } else {
                warning("'Config' entry in CONFIG (\"", config["config"], "\") must be function call like 'package:::fun()'")
                return(1)
            }
            for (pkg.name in setdiff(configPkg, .packages())) {
                if (debug)
                    message("Attemping to load package '", pkg.name, "'")
                if (!library(pkg.name, character.only=TRUE, logical.return=TRUE)) {
                    warning("could not load package '", pkg.name, "' needed for testing initialize/diff/finalize calls")
                    return(1)
                }
            }
            message("   Using Config = ", format(configFun))
            if (debug)
                message("   Calling config function ", format(configFun))
            res <- try(eval(configFun), silent=TRUE)
            if (inherits(res, "try-error")) {
                warning("failed to run config function call ", format(configFun), ": ", paste(as.character(res), collapse=" "))
                return(1)
            }
            if (!is.character(res) || is.null(names(res))) {
                warning("Config function ", format(configFun), " did not return a named character vector (returned ", paste(as.character(res), collapse=" "), ")")
                return(1)
            }
            names(res) <- casefold(names(res), upper=FALSE)
            config <- c(config, res)
        }

        # should we work out what the name of the package being tested, and add that too?
        depends <- tools:::.get_requires_from_package_db(config, "Depends")

        if (is.element("stoponerror", names(config))) {
            stopOnError <- try(eval(parse(text=config["stoponerror"])[[1]])!=0)
            if (inherits(stopOnError, "try-error")) {
                warning("could not interpret 'StopOnError' entry in CONFIG (\"", config["stoponerror"], "\") as a logical value")
                stopOnError <- FALSE
            } else if (length(stopOnError)!=1 || is.na(stopOnError)) {
                warning("could not interpret 'StopOnError' entry in CONFIG (\"", config["stoponerror"], "\") did not evaluate to a single TRUE/FALSE value")
                stopOnError <- FALSE
            } else {
                message("   Setting stopOnError=", stopOnError)
            }
        }

        if (length(depends))
            cat(paste("library('", unique(depends), "', character.only=TRUE)\n", sep=""), file = "startup.Rs", append = TRUE)

        if (is.element("initialize", names(config))) {
            initializeFun <- try(parse(text=config["initialize"])[[1]])
            if (!is.call(initializeFun)) {
                warning("could not parse 'Initialize' entry in CONFIG (\"", config["initialize"], "\") as a function call")
                return(1)
            } else {
                if (!is.name(initializeFun[[1]]) && as.character(initializeFun[[1]][[1]]) == ":::")
                    needPkg <- unique(c(needPkg, as.character(initializeFun[[1]][[2]])))
                message("   Using Initialize = ", format(initializeFun))
            }
        }
        if (is.element("finalize", names(config))) {
            finalizeFun <- try(parse(text=config["finalize"])[[1]])
            if (!is.call(finalizeFun)) {
                warning("could not parse 'Finalize' entry in CONFIG (\"", config["finalize"], "\") as a function call")
                return(1)
            } else {
                if (!is.name(finalizeFun[[1]]) && as.character(finalizeFun[[1]][[1]]) == ":::")
                    needPkg <- unique(c(needPkg, as.character(finalizeFun[[1]][[2]])))
                message("   Using Finalize = ", format(finalizeFun))
            }

        }
        if (is.element("diff", names(config))) {
            diffFun <- try(parse(text=config["diff"])[[1]])
            if (!is.call(diffFun)) {
                warning("could not parse 'Diff' entry in CONFIG (\"", config["diff"], "\") as a function call")
                return(1)
            } else {
                if (!is.name(diffFun[[1]]) && as.character(diffFun[[1]][[1]]) == ":::")
                    needPkg <- unique(c(needPkg, as.character(diffFun[[1]][[2]])))
                message("   Using Diff = ", format(diffFun))
            }
        }
    }

    if (length(needPkg)) {
        for (pkg.name in setdiff(needPkg, .packages())) {
            if (debug)
                message("Attemping to load package '", pkg.name, "'")
            if (!library(pkg.name, character.only=TRUE, logical.return=TRUE)) {
                warning("could not load package '", pkg.name, "' needed for testing initialize/diff/finalize calls")
                return(1)
            }
        }
    }

    if (!is.null(initializeFun)) {
        # Add a pattern=<pattern> actual argument to the call to initializeFun
        # if it does have a formal argument named 'pattern'
        init.args <- names(formals(eval(initializeFun[[1]])))
        if (!is.null(pattern) && is.element("pattern", init.args)) {
            initializeFun[length(initializeFun)+1] <- pattern
            names(initializeFun)[length(initializeFun)] <- "pattern"
        }
        # Add a subst=<subst> actual argument to the call to initializeFun
        # if it does have a formal argument named 'subst'
        if (!is.null(subst) && is.element("subst", init.args)) {
            initializeFun[length(initializeFun)+1] <- subst
            names(initializeFun)[length(initializeFun)] <- "subst"
        }
        # Add a debug=<debug> actual argument to the call to initializeFun
        # if it does have a formal argument named 'debug'
        if (!is.null(debug) && is.element("debug", init.args)) {
            initializeFun[length(initializeFun)+1] <- debug
            names(initializeFun)[length(initializeFun)] <- "debug"
        }
        if (debug)
            message("   Calling initialization function ", format(initializeFun))
        res <- try(eval(initializeFun), silent=TRUE)
        if (inherits(res, "try-error")) {
            warning("failed to run initialize function call ", format(initializeFun), ": ", paste(as.character(res), collapse=" "))
            return(1)
        }
        if (!is.atomic(res) || length(res)!=1 || is.na(res) || res != 0) {
            warning("initialize function call ", format(initializeFun), " ran successfully but returned non-zero value ",
                    if (length(res)!=1) paste("(length=", length(res), ")", sep=""), ": ",
                    paste(format(res), collapse="; "))
            return(1)
        }
    }

    Rinfiles <- dir(".", pattern="\\.Rin$")
    if (!run.preexisting.R.files) {
        if (debug && length(preexisting.Rin.files))
            message("   Not running these pre-existing .Rin files: ", paste(preexisting.Rin.files, collapse=" "))
        Rinfiles <- setdiff(Rinfiles, preexisting.Rin.files)
    }
    for(f in Rinfiles) {
        Rfile <- sub("\\.Rin$", ".R", f)
        message("   Creating ", sQuote(Rfile), " from ", f)
        cmd <- paste(shQuote(file.path(R.home(), "bin", "R")),
                     "CMD BATCH --no-timing --vanilla --slave", f)
        if (system(cmd))
            warning("creation of ", sQuote(Rfile), " failed")
        else if (file.exists(Rfile)) nfail <- nfail + runone(Rfile, stopOnError=stopOnError, debug=debug)
        if (nfail > 0) return(nfail)
    }

    Rfiles <- dir(".", pattern="\\.R$")
    if (!run.preexisting.R.files) {
        Rfiles <- setdiff(Rfiles, preexisting.R.files)
        if (debug && length(preexisting.R.files))
            message("   Not running these pre-existing .R files: ", paste(preexisting.R.files, collapse=" "))
    }
    for(f in Rfiles) {
        nfail <- nfail + runone(f, diffFun, stopOnError=stopOnError, debug=debug)
        if (nfail > 0) return(nfail)
    }

    if (!is.null(finalizeFun)) {
        if (debug)
            message("   Calling finalization function ", format(finalizeFun))
        res <- try(eval(finalizeFun), silent=TRUE)
        if (inherits(res, "try-error")) {
            warning("failed to run finalize function call ", format(finalizeFun), ": ", paste(as.character(res), collapse=" "))
            nfail <- nfail + 1
        } else if (!is.atomic(res) || length(res)!=1 || is.na(res) || res != 0) {
            nfail <- nfail + 1
            if (!file.exists("test-summary.fail")) {
                # don't need to give multiple indications of problems
                warning("finalize function call ", format(finalizeFun), " ran successfully but returned non-zero value ",
                        if (length(res)!=1) paste("(length=", length(res), ")", sep=""), ": ",
                        paste(format(res), collapse="; "))
             }
        }
    }

    return(nfail)
}

## compares 2 files -- function is the same as in package tools
Rdiff <- function(from, to, useDiff = FALSE)
{
    clean <- function(txt)
    {
        ## remove R header
        if(length(top <- grep("^(R version|R : Copyright)", txt,
                              perl = TRUE, useBytes = TRUE)) &&
           length(bot <- grep("quit R.$", txt, perl = TRUE, useBytes = TRUE)))
            txt <- txt[-(top[1]:bot[1])]
        ## remove BATCH footer
        nl <- length(txt)
        if(grepl("^> proc.time()", txt[nl-2])) txt <- txt[1:(nl-3)]
        ## regularize fancy quotes.
        txt <- gsub("(\xe2\x80\x98|\xe2\x80\x99)", "'", txt,
                      perl = TRUE, useBytes = TRUE)
        if(.Platform$OS.type == "windows") # not entirely safe ...
            txt <- gsub("(\x93|\x94)", "'", txt, perl = TRUE, useBytes = TRUE)
        pat <- '(^Time |^Loading required package|^Package [A-Za-z][A-Za-z0-9]+ loaded|^<(environment|promise|pointer): )'
        txt[!grepl(pat, txt, perl = TRUE, useBytes = TRUE)]
    }

    left <- clean(readLines(from))
    right <- clean(readLines(to))
    if (!useDiff && (length(left) == length(right))) {
        bleft <- gsub("[[:space:]]+", " ", left, perl=TRUE)
        bright <- gsub("[[:space:]]+", " ", right, perl=TRUE)
        if(all(bleft == bright)) return(0L)
        cat("\n")
        diff <- bleft != bright
        ## FIXME do run lengths here
        for(i in which(diff)) {
            cat(i,"c", i, "\n< ", left[i], "\n", "---\n> ", right[i], "\n",
                sep = "")
        }
        return(1L)
    } else {
        ## FIXME: use C code, or something like merge?
        ## The files can be very big.
        if(!useDiff) cat("\nfiles differ in number of lines:\n")
        a <- tempfile()
        b <- tempfile()
        writeLines(left, a)
        writeLines(right, b)
        return(system(paste("diff -bw", shQuote(a), shQuote(b))))
    }
}
