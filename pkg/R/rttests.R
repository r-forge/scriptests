# runScripTests() is intended to be called from a .R file in the tests directory
# e.g., like this:
#    library(ScripTests)
#    runScripTests()

runScripTests <- function(..., initializeFun = Quote(initializeTests()),
                            finalizeFun = Quote(summarizeTests()),
                            diffFun = Quote(ScripDiff()), subst=NULL,
                            quit=TRUE)
{
    cat("\n");
    status <- .runPackageTests(..., initializeFun=initializeFun, finalizeFun=finalizeFun,
                               diffFun=diffFun, run.preexisting.R.files=FALSE, subst=subst)
    # When run by "R CMD check", no output directly from the tests will appear on the
    # console.  The only output the user sees will be the last 13 lines from the first
    # .fail file that "R CMD check" files after getting a non-zero status result from
    # running a .R file.
    # Try to work out whether we were called from a .R file, and if so what was its name,
    # so that we can make the name of the file with the transcript of detailed comparisons
    # appear at the end of the .fail file so that it will be displayed to the user.
    test.transcript.file <- NULL
    if (!is.na(i <- match("-f", commandArgs()))) {
        test.transcript.file <- paste(commandArgs()[i+1], "out", sep="")
        test.transcript.file <- paste(c(rev(rev(strsplit(gsub("\\\\", "/", getwd(), perl=TRUE), "/")[[1]])[1:2]), test.transcript.file), collapse=.Platform$file.sep)
        cat("\nSee ", test.transcript.file, (if (status) ".fail"), " for", " a", " transcript", " of", " test", " comparisons", fill=T, sep="")
    }
    if (quit)
        q("no", status = status)
}

# setOldClass("RtTestSetResults")
# setOldClass("RtTestSetResultsSummary")

compareTranscriptAndOutput <- function(name, tests, results, progress=TRUE) {
    x <- list()
    # return a RtTestSetResults objects (a list of lists), each having components:
    #   status: one of "error", "warning", "info", "ok"
    #   msg: an informative message (multi-line as char vector)
    is.empty.command <- function(case) {
        return(is.element("comment", names(case)) && identical(case$comment, "> "))
    }
    ## see if we can strip empty commands from the end of the longer set
    while (length(results) > length(tests) && is.empty.command(results[[length(results)]]))
        results <- results[-length(results)]
    while (length(tests) > length(results) && is.empty.command(tests[[length(tests)]]))
        tests <- tests[-length(tests)]
    if (length(tests) != length(results)) {
        msg <- "Number of commands in tests and results files differs!"
        haltedEarly <- FALSE
        if (length(tests) > length(results)) {
            msg <- c(msg, "  tests file has more commands, first extra one is:",
                     paste("  ", tests[[length(results)+1]]$input, sep=""))
            xtraTests <- tests[-seq(along=results)]
            xtraResults <- list()
            tests <- tests[seq(along=results)]
            if (any(regexpr("execution halted", results[[length(results)]]$output, ignore.case=TRUE)>0)) {
                haltedEarly <- TRUE
                msg <- c(msg, "Execution of tests was halted early")
            }
        } else {
            msg <- c(msg, "  results file has more commands, first extra one is:",
                     paste("  ", results[[length(tests)+1]]$input, sep=""))
            xtraResults <- results[-seq(along=tests)]
            xtraTests <- list()
            results <- results[seq(along=tests)]
        }
        if (progress)
            cat(paste("Error in", name), msg, sep="\n")
        # need double nesting of list because of unlist( , recursive=FALSE) below
        x <- c(x, list(list(list(msg=msg, status="error"))))
    }
    x <- c(x, mapply(tests, results, seq(along=tests), FUN=function(test, result, testnum) {
        ## check that input matches
        res <- list()
        if (!identical(all.equal(test$input, result$input), TRUE)) {
            res <- list(list(status="warning", testnum=testnum,
                             msg=c("Internal inconsistency: mismatch between test input & input from transcript",
                                   "Test input:", test$input,
                                   "Transcript input:", result$input)))
        }
        res <- c(res, list(compareSingleTest(test$input, test$control, test$output, result$output, testnum, name, progress)))
        return(res)
    }, SIMPLIFY=FALSE, USE.NAMES=FALSE))
    x <- unlist(x, use.names=FALSE, recursive=FALSE)
    if (progress)
        cat("\n")
    class(x) <- "RtTestSetResults"
    attr(x, "testname") <- name
    x
}

summary.RtTestSetResultsList <- function(object, ...) {
    cat("+++++ Test summary +++++\n")
    smy <- do.call("rbind", lapply(object, function(x) {xs <- summary(x) ; n <- xs$n; data.frame(n, "tests with", errors=xs$counts[4], "errors,", warnings=xs$counts[3], "warnings and", messages=xs$counts[2], "messages")}))
    smy <- smy[order(smy$errors, smy$warnings, smy$messages), , drop=FALSE]
    smy <- rbind(smy, total=smy[1,,drop=F])
    n <- nrow(smy)
    smy[n,"n"] <- sum(smy$n[-n])
    smy[n,"errors"] <- sum(smy$errors[-n])
    smy[n,"warnings"] <- sum(smy$warnings[-n])
    smy[n,"messages"] <- sum(smy$messages[-n])
    class(smy) <- c("RtTestSetResultsList.summary", "data.frame")
    return(smy)
}

print.RtTestSetResultsList <- function(object, ..., transcript=FALSE) {
    if (transcript) {
        stop("can only print a transcript for one file in the list, e.g., use print(", paste(deparse(substitute(object)), collapse=" "), "[[1]], transcript=TRUE)")
    }
    NextMethod()
}

print.RtTestSetResultsList.summary <- function(x, ...) {
    cat(apply(format(cbind(paste(rownames(x), ":", sep=""), x), justify="left"), 1, paste, collapse=" "), sep="\n")
}

print.RtTestSetResults <- function(x, ..., transcript=FALSE) {
    if (transcript) {
        cat("* Transcript of actual output from running commands in '", attr(x, "testname"), "':\n", sep="")
        lapply(x, function(res) {
            if (length(res$comment))
                cat(res$comment, sep="\n")
            if (length(res$transcript))
                cat(res$transcript, sep="\n")
        })
    } else {
        lapply(x, function(res) {
            if (res$status=="ok")
                cat(".")
            else
                cat("", paste("#@", res$msg), sep="\n")
        })
        cat("\n")
    }
    invisible(x)
}

summary.RtTestSetResults <- function(object, ...) {
    y <- table(factor(sapply(object, "[[", "status"), levels=c("ok", "info", "warning", "error")))
    n <- object[[length(object)]]$i
    structure(list(n=n, counts=y, testname=attr(object, "testname")), class="RtTestSetResults.summary")
}

print.RtTestSetResults.summary <- function(x, ...) {
    cat(x$testname, ": ", x$n, " tests with ",
        x$counts["error"], " errors, ",
        x$counts["warning"], " warnings and ",
        x$counts["info"], " messages\n", sep="")
    invisible(x)
}

compareSingleTest <- function(input, control, target, actual, testnum, testname, progress) {
    ## Return a list containing the following elements:
    ##   status: one of 'ok', 'error', 'warn', 'info'
    ##   msg: character vector describing differences (for human readability)
    ## A zero length return value indicates a match.
    ## Strip trailing & leading white space, convert all whitespace to single, remove blank lines.
    ## If the control text contains a line starting with "#@ ignore output" (case-insensitive),
    ## then the match is successful, regardless of the actual output.
    ## All lines in the control text that start with "#@ gsub(pattern, replacement, var)",
    ## where 'var' is 'target' or 'actual' (no quotes) are applied as substitutions, in order,
    ## to the target or actual text, before attempting a match.
    mismatch.status <- "error"
    status.msg <- NULL
    ignore.whitespace <- TRUE
    ignore.linebreaks <- FALSE
    diff.msg <- NULL # message to output if there are differences
    if (!is.null(control)) {
        if (any(regexpr('^\\#@ +ignore[- ]output', control, ignore.case=TRUE)>0))
            target <- actual <- character(0)
        for (line in control) {
            if (regexpr('^\\#@ +gsub\\(', casefold(line, upper=FALSE))>0) {
                expr <- try(parse(text=gsub("^\\#@ *", "", line, perl=TRUE)), silent=TRUE)
                v <- all.vars(expr)
                if (is(expr, "try-error")) {
                    warning("parse error in test-control line '", line, "': ",
                            gsub("Error in parse\\(file, n, text, prompt\\) :[ \n\t]+", "", expr, perl=TRUE))
                } else if (!all(is.element(v, c("target", "actual", "both")))) {
                    warning("ignoring test-control line '", line, "' uses variables other than 'target', 'actual' and 'both'")
                } else if (length(v)==0) {
                    warning("ignoring test-control line '", line, "' that refers to neither 'target', 'actual' nor 'both'")
                } else if (length(v)>1) {
                    warning("ignoring test-control line '", line, "' that refers to more than one of 'target', 'actual' and 'both'")
                } else if (v=="target") {
                    res <- try(eval(do.call("substitute", list(expr[[1]], list(target=target)))), silent=TRUE)
                    if (is(res, "try-error"))
                        warning("error in running gsub control line '", line, "': ", as.character(res))
                    else
                        target <- res
                } else if (v=="actual") {
                    res <- try(eval(do.call("substitute", list(expr[[1]], list(actual=actual)))), silent=TRUE)
                    if (is(res, "try-error"))
                        warning("error in running gsub control line '", line, "': ", as.character(res))
                    else
                        actual <- res
                } else if (v=="both") {
                    res <- try(eval(do.call("substitute", list(expr[[1]], list(both=target)))), silent=TRUE)
                    if (is(res, "try-error"))
                        warning("error in running gsub control line '", line, "': ", as.character(res))
                    else
                        target <- res
                    res <- try(eval(do.call("substitute", list(expr[[1]], list(both=actual)))), silent=TRUE)
                    if (is(res, "try-error"))
                        warning("error in running gsub control line '", line, "': ", as.character(res))
                    else
                        actual <- res
                }
            } else if (regexpr('^\\#@ +warn[- ]only', line, ignore.case=TRUE)>0) {
                mismatch.status <- "warning"
                msg <- gsub('^\\#@ +warn[- ]only:? ?', '', line, perl=TRUE)
                if (msg != line && nchar(line)>0)
                    diff.msg <- msg
                status.msg <- c(status.msg, line)
            } else if (regexpr('^\\#@ +info[- ]only', line, ignore.case=TRUE)>0) {
                mismatch.status <- "info"
                msg <- gsub('^\\#@ +info[- ]only:? ?', '', line, perl=TRUE)
                if (msg != line && nchar(line)>0)
                    diff.msg <- msg
                status.msg <- c(status.msg, line)
            } else if (regexpr('^\\#@ +keep[- ]whitespace', line, ignore.case=TRUE)>0) {
                ignore.whitespace <- FALSE
            } else if (regexpr('^\\#@ +ignore[- ]linebreaks', line, ignore.case=TRUE)>0) {
                ignore.linebreaks <- TRUE
            } else if (regexpr('^\\#@ +diff[- ]msg:', line, ignore.case=TRUE)>0) {
                diff.msg <- c(diff.msg, gsub('^\\#@ +diff-msg:? ?', '', line, perl=TRUE))
            } else if (regexpr('^\\#@ +ignore[- ]output', line, ignore.case=TRUE)>0) {
            } else if (regexpr('^\\#@#', line)<1) {
                warning("cannot understood test-control line (ignoring): '", line, "'")
            }
        }
    }
    if (ignore.linebreaks) {
        ## Remove newlines and join lines if necessary.
        target <- gsub("\n", "", paste(target, collapse = ""), perl=TRUE)
        actual <- gsub("\n", "", paste(actual, collapse = ""), perl=TRUE)
    }
    # cannonicalize whitespace
    if (ignore.whitespace) {
        target <- gsub("^[[:space:]]*", "", target, perl=TRUE)
        target <- gsub("[[:space:]]*$", "", target, perl=TRUE)
        target <- gsub("[[:space:]]{2,}", " ", target, perl=TRUE)
        target <- target[target!=""]
        actual <- gsub("^[[:space:]]*", "", actual, perl=TRUE)
        actual <- gsub("[[:space:]]*$", "", actual, perl=TRUE)
        actual <- gsub("[[:space:]]{2,}", " ", actual, perl=TRUE)
        actual <- actual[actual!=""]
    }
    target.len <- length(target)
    actual.len <- length(actual)
    if (length(target) < length(actual))
        target <- c(target, rep("", length(actual) - length(target)))
    if (length(target) > length(actual))
        actual <- c(actual, rep("", length(target) - length(actual)))
    i <- target == actual
    if (length(i) && !all(i)) {
        msg <- c(paste("* ", casefold(substring(mismatch.status, 1, 1), upper=TRUE), substring(mismatch.status, 2),
                       " mismatch on output for test number ", testnum, " in ", testname, ":", sep=""),
                 status.msg, input)
        if (!is.null(diff.msg))
            msg <- c(msg, diff.msg)
        if (target.len==0) {
            msg <- c(msg, paste("* Empty target output, actual output is:"), paste("", actual, sep=""))
        } else if (actual.len==0) {
            msg <- c(msg, paste("* No actual output, but target output", if (length(target)>3) "began with:" else "is:"),
                     target[seq(len=min(3, length(target)))])
        } else if (actual.len+target.len <= 10) {
            msg <- c(msg, "* Target output:", paste("", target[seq(target.len)], sep=""),
                     "* Actual output:", paste("", actual[seq(actual.len)], sep=""))
        } else {
            msg <- c(msg, paste("* Output differs first at line ", which(!i)[1], ":"),
                     paste("  target:", target[which(!i)[1]]),
                     paste("  actual:", actual[which(!i)[1]]))
        }
        status <- mismatch.status
    } else {
        msg <- character(0)
        status <- "ok"
    }
    if (progress)
        if (status=="ok")
            cat(".")
        else
            cat("", msg, sep="\n")
    res <- list(status=status, msg=msg, i=testnum)
    return(res)
}

parseTranscriptFile <- function(file, ignoreUpToRegExpr=NULL, ignoreAfterRegExpr=NULL, subst=NULL)
{
    ## This function reads a transcript a file, separates commands and output,
    ## parses the commands, and returns a list with each element containing
    ## a list with the following elements:
    ##   input/comment: the exact text that contained the commands (including prompts)
    ##   expr: the parsed expression (can be NULL if source is a comment)
    ##   control: control text
    ##   output: the output that apparently came from the command (can be character(0))
    ##
    ## file : [character] the name of the file to read
    ##
    lines <- readLines(file, -1, warn=FALSE)
    # Ignore intial blank lines
    blank <- grep("^[ \\t]*$", lines, perl=TRUE, invert=TRUE)
    if (length(blank) && blank[1] > 1)
        lines <- lines[-seq(len=blank[1]-1)]
    if (!is.null(ignoreUpToRegExpr)) {
        i <- grep(ignoreUpToRegExpr, lines, perl=TRUE)
        if (length(i)>0)
            lines <- lines[-seq(len=i[1])]
        # Ignore intial blank lines
        blank <- grep("^[ \\t]*$", lines, perl=TRUE, invert=TRUE)
        if (length(blank) && blank[1] > 1)
            lines <- lines[-seq(len=blank[1]-1)]
    }
    if (!is.null(ignoreAfterRegExpr)) {
        i <- grep(ignoreAfterRegExpr, lines, perl=TRUE)
        if (length(i)>0)
            lines <- lines[-seq(len=i[1])]
    }
    if (length(subst)) {
        if (!is.character(subst) || is.null(names(subst)))
            stop("subst must be a named character vector")
        for (i in seq(along=subst)) {
            pattern <- names(subst)[i]
            repl <- subst[i]
            if (pattern=="")
                stop("subst cannot have empty names -- the names are the pattern to replace")
            lines <- gsub(pattern, repl, lines, perl=TRUE)
        }
    }

    ## calculate a code for each line:
    ##   0: output
    ##   1: command
    ##   2: continuation
    ##   3: comment or empty command
    ##   4: control
    lineType <- c("output", "command", "continuation", "comment/empty", "control")
    code <- ifelse(regexpr("^> ?(#|[:space:]*$)", lines)>0, 3,
                   ifelse(regexpr("^> ", lines)>0, 1,
                          ifelse(regexpr("^\\+ ", lines)>0, 2,
                                 ifelse(regexpr("^#@", lines)>0, 4, 0))))
    ## Identify blocks of contiguous comments, command+continuation, & output
    ## Insert a separators that between adjust lines starting with ">"
    ## because these must be separate commands (the first having no output)
    ## Convert command+continuation to all command + separator (-1)
    code2 <- as.vector(rbind(code, ifelse(code==1 & c(code[-1],0)==1, -1, -2)))
    code2 <- code2[code2 != -2]
    code2 <- replace(code2, code2==2, 1)
    runs <- rle(code2)
    i <- runs$values != -1
    runs$values <- runs$values[i]
    runs$lengths <- runs$lengths[i]
    nblocks <- sum(is.element(runs$values, c(1, 3)))
    i <- 1 # counter in lines
    j <- 1 # counter in runs
    blocks <- lapply(seq(len=nblocks), function(k) {
        if (runs$values[j]==3) {
            res <- list(comment=lines[seq(i,len=runs$lengths[j])])
            i <<- i + runs$lengths[j]
            j <<- j + 1
        } else if (runs$values[j]==1) {
            res <- list(input=lines[seq(i,len=runs$lengths[j])])
            i <<- i + runs$lengths[j]
            j <<- j + 1
            while (is.element(runs$values[j], c(0,4))) {
                if (runs$values[j]==0) {
                    res$output <- c(res$output, lines[seq(i,len=runs$lengths[j])])
                    i <<- i + runs$lengths[j]
                    j <<- j + 1
                } else {
                    res$control <- c(res$control, lines[seq(i,len=runs$lengths[j])])
                    i <<- i + runs$lengths[j]
                    j <<- j + 1
                }
            }
            text <- gsub("^[>+] ?", "", res$input, perl=TRUE)
            res$expr <- try(parse(text=text, srcfile=NULL), silent=TRUE)
            ## try to make a syntax error message look like it does at the prompt
            if (is(res$expr, "try-error"))
                res$expr[1] <- gsub("Error in parse\\(text = text, srcfile = NULL\\) :[ \n\t]+", "Error: ", res$expr[1], perl=TRUE)
        } else if (runs$values[j]==4) {
            warning("ignoring orphaned control lines at line ", i, "(\"", lines[i], "\")")
        } else {
            stop("not expecting line of type '", lineType[runs$values[j]+1], "' at line ", i,
                 " (", paste("\"", lines[seq(i, len=min(runs$lengths[j], 3))], "\"", collapse=", ", sep=""), ")")
        }
        return(res)
    })
    return(blocks)
}

# is setupTests() needed for anything?
# setupTests <- function(debug=FALSE, create.Rout.save=FALSE, addSelfCheck=FALSE) initializeTests(debug, create.Rout.save, addSelfCheck)

initializeTests <- function(debug=FALSE, create.Rout.save=FALSE, addSelfCheck=FALSE, pattern=NULL, subst=NULL) {
    # Create .R and .Rout.save files for each .Rt file
    wd <- getwd()
    test.dir <- basename(dirname(wd)) # should get something like mypackage.Rcheck
    pkg.name <- NULL
    if (regexpr("\\.Rcheck$", test.dir) > 0)
        pkg.name <- sub("\\.Rcheck$", "", test.dir)

    # process all .R files - if a .Rout.save file exists, generate a .Rt.save file
    for (cmdIn in list.files(pattern=".*\\.[Rr]$")) {
        if (!is.null(pattern) && !length(grep(pattern, cmdIn))) {
            if (debug)
                message(" Skipping file ", cmdIn)
            next
        }
        rOutSave <- gsub("\\.R$", ".Rout.save", cmdIn, perl=TRUE)
        if (file.exists(rOutSave)) {
            rtSave <- gsub("\\.R$", ".Rt.save", cmdIn, perl=TRUE)
            if (debug)
                message(" Pre-processing tests in ", cmdIn, "/", rOutSave, " to generate ", rtSave)
            tests <- parseTranscriptFile(rOutSave)
            env <- new.env()
            save(list="tests", file=rtSave, envir=env)
        } else {
            if (debug)
                message(" No saved output file for tests in ", cmdIn, "; just checking that tests run without stopping with an error")
        }
    }

    # process all .Rt files (generate a .R and .Rt.save and optionally .Rout.save)
    for (rtIn in list.files(pattern=".*\\.[Rr]t$")) {
        if (!is.null(pattern) && !length(grep(pattern, rtIn))) {
            if (debug)
                message(" Skipping file ", rtIn)
            next
        }
        rOutSave <- gsub("\\.Rt$", ".Rout.save", rtIn, perl=TRUE)
        rtSave <- gsub("\\.Rt$", ".Rt.save", rtIn, perl=TRUE)
        cmdOut <- gsub("\\.Rt$", ".R", rtIn, perl=TRUE)
        if (debug)
            message(" Pre-processing tests in ", rtIn, " to generate ", cmdOut, if (create.Rout.save) paste(",", rOutSave), ", and ", rtSave)
        tests <- parseTranscriptFile(rtIn, subst=subst)
        env <- new.env()
        test.obj.name <- paste(gsub("\\.Rt$", "", rtIn), ".tests", sep="", perl=TRUE)
        assign(test.obj.name, tests, envir=env)
        save(list="tests", file=rtSave, envir=env)
        ## add a comment to the beginning for what is printed in the file
        tests <- c(list(list(comment=paste("> # generated automatically in", getwd(), "on", Sys.time())),
                        if (!is.null(pkg.name)) list(input=paste("> library('", pkg.name, "', char=TRUE)", sep=""))
                        else list(input=paste("> # could not work out package name from getwd: '", wd, "'", sep="")),
                        list(input="> searchpaths() # seeing where these came from can be useful for debugging"),
                        list(comment="> # End of RtTests preamble")),
                   tests)

        ## write out the commands and the desired output
        cmdOutCon <- file(cmdOut, "w")
        if (create.Rout.save)
            rOutSaveCon <- file(rOutSave, "w")
        # do in a local() block so we can use on.exit()
        local({
            on.exit(close(cmdOutCon))
            if (create.Rout.save)
                on.exit(close(rOutSaveCon))
            lapply(tests, function(test) {
                if (!is.null(test$comment)) {
                    commands <- test$comment
                    output <- NULL
                } else if (!is.null(test$input)) {
                    commands <- test$input
                    output <- test$output
                } else {
                    stop("illegal test structure: no 'comment' or 'input' component")
                }
                commandsIn <- gsub("^[>+] ?", "", grep("^[>+]", commands, value=TRUE, perl=TRUE), perl=TRUE)
                cat(file=cmdOutCon, paste(commandsIn, "\n", sep=""), sep="")
                if (create.Rout.save)
                    cat(file=rOutSaveCon, paste(commands, "\n", sep=""), sep="")
                if (create.Rout.save && length(output))
                    cat(file=rOutSaveCon, paste(output, "\n", sep=""), sep="")

            })
            if (addSelfCheck) {
                cat(file=cmdOutCon, "# End of RtTests output\n")
                cat(file=cmdOutCon, "flush(stdout())\n")
                cat(file=cmdOutCon, "require('RtTests', character.only=TRUE)\n")
                cat(file=cmdOutCon, "RtTests:::checkTestOutput('", rtIn, "', '", rtSave, "')\n", sep="")
            }
            close(cmdOutCon)
            if (create.Rout.save)
                close(rOutSaveCon)
            on.exit()
        })
    }
    return(0)
}


checkTestOutput <- function(rtIn, rtSave=paste(rtIn, ".save", sep=""), debug=TRUE) {
    rtOut <- gsub("\\.Rt$", ".Rout", rtIn, perl=TRUE)
    rtFail <- gsub("\\.Rt$", ".Rt.fail", rtIn, perl=TRUE)
    rtLog <- paste(rtIn, ".log", sep="")
    if (!file.exists(rtIn)) {
        msg <- paste("checkTestOutput: cannot find original test file '", rtIn, "' in '", getwd(), "'\n", sep="")
        cat(file=rtFail, msg)
        cat(file=stderr(), msg)
        return(NULL)
    }
    if (!file.exists(rtSave)) {
        msg <- paste("checkTestOutput: cannot find saved-test-object file '", rtSave, "' in '", getwd(), "'\n", sep="")
        cat(file=rtFail, msg)
        cat(file=stderr(), msg)
        return(NULL)
    }
    if (!file.exists(rtOut)) {
        msg <- paste("checkTestOutput: cannot actual test output file '", rtOut, "' in '", getwd(), "'\n", sep="")
        cat(file=rtFail, msg)
        cat(file=stderr(), msg)
        return(NULL)
    }
    sink(stderr())
    if (debug)
        cat("  * Loading saved transcript object from file \"", rtSave, "\" ...\n", sep="", file=stderr())

    testObjName <- load(file=rtSave, envir=as.environment(-1))
    if (testObjName[1] != "tests")
        tests <- get(testObjName[1])
    cat("  * Parsing actual test output from file \"", rtOut, "\" ...\n", sep="", file=stderr())
    resList <- parseTranscriptFile(rtOut, ignoreUpToRegExpr="> # End of RtTests preamble", ignoreAfterRegExpr="> # End of RtTests output")
    res <- compareTranscriptAndOutput(sub(".Rout", ".Rt", rtOut), tests, resList, progress=TRUE)
    res.summary <- summary(res)
    print(res.summary)
    sink()
    sink(rtLog)
    print(res)
    print(res.summary)
    sink()
    # Incrementally add to the summary in test-summary.txt, updating the total
    testResultsFile <- "test-summary.txt"
    # Test summaries are lines like this:
    #   1        2 3     4    5 6       7 8        9   10 11
    #   plus.Rt: 4 tests with 0 errors, 0 warnings and 0 messages
    if (file.exists(testResultsFile)) {
        testResults <- scan("test-summary.txt", quiet=T, what=list(name="", ntests=0, NULL, NULL, nerr=0, NULL, nwarn=0, NULL, NULL, nmess=0, NULL), fill=T)
        if (length(testResults$name)>0 && testResults$name[length(testResults$name)]=="total:")
            testResults <- lapply(testResults, "[", -length(testResults$name))
    } else {
        testResults <- list(name=character(0), ntests=numeric(0), c1=NULL,
                                  c2=NULL, nerr=numeric(0), c3=NULL,
                                  nwarn=numeric(0), c4=NULL, c5=NULL,
                                  nmess=numeric(0), c6=NULL)
    }
    i <- match(paste(rtIn, ":", sep=""), testResults$name, nomatch=length(testResults$name)+1)
    testResults$name[i] <- paste(rtIn, ":", sep="")
    testResults$ntests[i] <- res.summary$n
    testResults$nerr[i] <- res.summary$counts["error"]
    testResults$nwarn[i] <- res.summary$counts["warning"]
    testResults$nmess[i] <- res.summary$counts["info"]
    # add a line for the totals
    i <- length(testResults$name)+1
    testResults$name[i] <- "total:"
    testResults$ntests[i] <- sum(testResults$ntests, na.rm=T)
    testResults[[3]] <- "tests"
    testResults[[4]] <- "with"
    testResults$nerr[i] <- sum(testResults$nerr, na.rm=T)
    testResults[[6]] <- "errors,"
    testResults$nwarn[i] <- sum(testResults$nwarn, na.rm=T)
    testResults[[8]] <- "warnings"
    testResults[[9]] <- "and"
    testResults$nmess[i] <- sum(testResults$nmess, na.rm=T)
    testResults[[11]] <- "messages"
    # write out to a file "test-summary.txt"
    sink(testResultsFile)
    cat(do.call("paste", lapply(testResults, format)), sep="\n")
    sink()
    # and write the same thing to "test-summary.fail" if there are any errors
    testResultsFile <- "test-summary.fail"
    if (sum(testResults$nerr, na.rm=T) > 0) {
        sink(testResultsFile)
        cat(do.call("paste", lapply(testResults, format)), sep="\n")
        sink()
    }
    return(res)
}

ScripDiff <- function(commandfile, outfile=gsub("\\.R$", ".Rout", commandfile, perl=TRUE), savefile=paste(outfile, ".save", sep=""), debug=FALSE) {
    rtIn <- gsub("\\.R$", ".Rt", commandfile, perl=TRUE)
    rtSave <- gsub("\\.R$", ".Rt.save", commandfile, perl=TRUE)
    sumfile <- "test-summary.txt"
    if (file.exists(rtIn)) {
        # tests were generated from a .Rt file
        failfile <- paste(rtIn, ".fail", sep="")
        logfile <- paste(rtIn, ".log", sep="")
        ignoreUpToRegExpr <- "> # End of RtTests preamble"
        ignoreAfterRegExpr <- "> # End of RtTests output"
    } else {
        # tests were generated in a pre-existing .R file
        # if there is a corresponding .Rout.save file, use the .Rt.save
        # file that was generated by initializeTests()
        failfile <- paste(commandfile, ".fail", sep="")
        logfile <- paste(commandfile, ".log", sep="")
        ignoreUpToRegExpr <- "Type 'q\\(\\)' to quit R"
        ignoreAfterRegExpr <- NULL
        if (!file.exists(savefile)) {
            message("checkTestOutput: nothing to compare against for ", commandfile, "\n")
            return(0L)
        }
    }
    if (!file.exists(rtSave)) {
        msg <- paste("checkTestOutput: cannot find saved-test-object file '", rtSave, "' in '", getwd(), "'\n", sep="")
        cat(file=failfile, msg)
        cat(file=stderr(), msg)
        message(msg)
        return(NULL)
    }
    if (!file.exists(outfile)) {
        msg <- paste("checkTestOutput: cannot find actual test output file '", outfile, "' in '", getwd(), "'\n", sep="")
        cat(file=failfile, msg)
        cat(file=stderr(), msg)
        message(msg)
        return(NULL)
    }
    sink(stderr())
    if (debug) {
        cat("  * Loading saved transcript object from file \"", rtSave, "\" ...\n", sep="", file=stderr())
    }

    testObjName <- load(file=rtSave, envir=as.environment(-1))
    if (testObjName[1] != "tests")
        tests <- get(testObjName[1])
    if (debug)
        cat("  * Parsing actual test output from file \"", outfile, "\" ...\n", sep="", file=stderr())
    resList <- parseTranscriptFile(outfile, ignoreUpToRegExpr=ignoreUpToRegExpr, ignoreAfterRegExpr=ignoreAfterRegExpr)
    res <- compareTranscriptAndOutput(sub(".Rout", ".Rt", outfile), tests, resList, progress=TRUE)
    res.summary <- summary(res)
    print(res.summary)
    sink()
    sink(logfile)
    print(res)
    print(res.summary)
    sink()
    sink(sumfile, append=TRUE)
    print(res.summary)
    sink()
    return(0L)
}

summarizeTests <- function(debug=FALSE) {
    testResultsFile <- "test-summary.txt"
    if (file.exists(testResultsFile)) {
        all.res <- readLines(testResultsFile, -1)
        system("cp test-summary.txt test-summary.bak")
    } else {
        all.res <- character(0)
    }
    # all.res <- sapply(list.files(pattern=".*Rt\\.sum$"), readLines, 1)
    i <- regexpr("^.*: [0-9]+ tests with [0-9]+ errors, [0-9]+ warnings and [0-9]+ messages", all.res) >= 1
    if (!all(i)) {
        problem.lines <- all.res[!i]
        problem.lines <- gsub(":.*$", ": ...", problem.lines, perl=TRUE)
        problem.lines <- substring(problem.lines, 1, 40)
        warning("malformed lines in '", testResultsFile, "': ", paste('"', problem.lines, '"', sep="", collapse=", "))
    }
    all.res <- all.res[i]
    all.res.con <- textConnection(all.res)
    testResults <- scan(all.res.con, quiet=T, what=list(name="", ntests=0, NULL, NULL, nerr=0, NULL, nwarn=0, NULL, NULL, nmess=0, NULL), fill=T)
    close(all.res.con)
    if (length(testResults$name)>0 && testResults$name[length(testResults$name)]=="total:")
        testResults <- lapply(testResults, "[", -length(testResults$name))
    # add a line for the totals
    i <- length(testResults$name)+1
    testResults$name[i] <- "total:"
    testResults$ntests[i] <- sum(testResults$ntests, na.rm=T)
    testResults[[3]] <- "tests"
    testResults[[4]] <- "with"
    totalErrors <- testResults$nerr[i] <- sum(testResults$nerr, na.rm=T)
    testResults[[6]] <- "errors,"
    testResults$nwarn[i] <- sum(testResults$nwarn, na.rm=T)
    testResults[[8]] <- "warnings"
    testResults[[9]] <- "and"
    testResults$nmess[i] <- sum(testResults$nmess, na.rm=T)
    testResults[[11]] <- "messages"
    i <- order(testResults$nerr, testResults$nwarn, testResults$nmess, testResults$name)
    testResults <- lapply(testResults, function(x, i) if (length(x)>1) x[i] else x, i)
    # write out to a file "test-summary.txt"
    # rewrite the whole output sorted with columns lined up
    sink(testResultsFile, append=FALSE)
    # cat(paste(sapply(testResults, function(x) x[length(x)]), collapse=" "), sep="\n")
    cat(do.call("paste", lapply(testResults, format)), sep="\n") # the whole thing
    sink()
    # and write the same thing to "test-summary.fail" if there are any errors
    testResultsFile <- "test-summary.fail"
    if (totalErrors > 0) {
        sink(testResultsFile)
        cat(do.call("paste", lapply(testResults, format)), sep="\n")
        sink()
    }
    lines <- do.call("paste", lapply(testResults, format))
    lines <- c(lines[-length(lines)], "### Overall", lines[length(lines)])
    if (totalErrors > 0) {
        firstError <- which(testResults$nerr > 0)[1]
        lines <- c(lines[seq(1, len=firstError-1)],
                   paste("### ", sum(testResults$nerr)-1, " file", (if (sum(testResults$nerr)!=2) "s")," with errors", sep=""),
                   lines[seq(firstError, length(lines))])
    } else {
        firstError <- length(testResults$nerr) # not really, but the right numbers will be output downstream
    }
    cat(paste("### Test Summary: ", firstError-1, " file", (if (firstError!=2) "s")," without errors", sep=""), lines, sep="\n")
    return(totalErrors)
}

if (F) {
    # was using this in an earlier incarnation
testWrapper <- function(pkg, dir=file.path(paste(pkg, ".Rcheck", sep=""), "tests")) {
    cwd <- getwd()
    on.exit(setwd(cwd))
    setwd(dir)
    existing.files <- list.files()
    status <- .runPackageTests()
    new.files <- setdiff(list.files(), existing.files)
    if (length(new.files)) {
        cat("* Removing ", length(new.files), " new files: ", paste(new.files, collapse=", "), "\n", sep="")
        file.remove(new.files)
    }
    return(status)
}
}

