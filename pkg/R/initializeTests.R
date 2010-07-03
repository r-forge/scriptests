initializeTests <- function(debug=FALSE, create.Rout.save=FALSE, addSelfCheck=FALSE, pattern=NULL, subst=NULL) {
    # Create .R and .Rout.save files for each .Rt file
    wd <- getwd()
    if (debug)
        message("   initializeTests: wd=", wd)
    # Expect that we are running in .../<pkg.dir>.Rcheck/tests
    test.dir <- basename(dirname(wd)) # should get something like mypackage.Rcheck
    pkg.name <- NULL
    message("   initializeTests: debug=", debug)
    if (regexpr("\\.Rcheck$", test.dir) > 0) {
        # Can't rely on "*" being the package name in "*.Rcheck", e.g.,
        # in r-forge directory structure, packages are in mypackage/pkg/{DESCRIPTION,R,man} etc
        # and tests go into mypackage/pkg.Rcheck.  So get the package name
        # from the log messages in <pkg>.Rcheck/00install.out
        if (debug)
            message("   Looking for ", file.path(dirname(wd), "00install.out"))
        if (file.exists(file.path(dirname(wd), "00install.out"))) {
            pkg.name <- gsub(")", "", gsub("* DONE (", "", fixed=TRUE, grep("* DONE ", readLines(file.path(dirname(wd), "00install.out")), fixed=TRUE, value=TRUE)))
            if (debug)
                message("   Read pkg.name= '", pkg.name, "'")
        }
        if (length(pkg.name) && nchar(pkg.name)==0)
            pkg.name <- NULL
    }

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
                        if (!length(pkg.name)) list(input=paste("> library('", pkg.name, "', char=TRUE)", sep=""))
                        else list(input=paste("> # could not work out package name from getwd: '", wd, "/00install.out'", sep="")),
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

