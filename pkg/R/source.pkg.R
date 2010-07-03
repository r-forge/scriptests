source.pkg <- function(pkg.dir=mget("working.package.dir", envir=globalenv())[[1]],
                       pattern=".*", suffix="\\.R$", dlls=c("no", "check"), pos=2,
                       path=mget("working.package.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]]) {
    dlls <- match.arg(dlls)
    if (!missing(pkg.dir))
        assign("working.package.dir", pkg.dir, envir=globalenv())
    if (!missing(path))
        assign("working.package.path", path, envir=globalenv())
    if (!file.exists(pkg.path(path, pkg.dir)))
        stop("cannot find package directory ", pkg.path(path, pkg.dir), " (supply path=... ?)")
    if (file.exists(file.path(pkg.path(path, pkg.dir), "DESCRIPTION"))) {
        desc <- read.dcf(file.path(pkg.path(path, pkg.dir), "DESCRIPTION"))
        desc <- structure(as.list(as.character(desc[1,])), names=casefold(colnames(desc)))
    }
    pkg.name <- read.pkg.name(path, pkg.dir)
    problems <- list()
    # Load dependencies before we attach the environment for our package code, so that required
    # libraries come after in search path -- if the dependencies come before, we won't find them.
    if (!is.null(desc$depends)) {
        # Depends is comma separated
        depends <- try(parse(text=paste("c(", gsub("\\([^()]*\\)", "", desc$depends), ")")))
        cat("Checking Depends from DESCRIPTION\n")
        if (is(depends, "try-error")) {
            warning("could not parse Depends field in DESCRIPTION file: ", desc$depends)
        } else {
            for (dep in setdiff(sapply(depends[[1]][-1], as.character), "R")) {
                if (any(is.element(paste(c("pkgcode", "package"), dep, sep=":"), search()))) {
                    cat("  Depends element ", dep, " is already loaded\n", sep="")
                } else {
                    cat("Doing require(", dep, ") to satisfy Depends in DESCRIPTION\n", sep="")
                    if (!require(dep, character.only=TRUE, quietly=TRUE, warn.conflicts=FALSE, save=FALSE))
                        problems <- c(problems, structure("problems loading", names=paste("dependency", dep)))
                }
            }
        }
    }

    # Create a new environment on the search path
    if (!missing(pkg.dir) && missing(pos))
        pos <- match(paste("pkgcode", pkg.name, sep=":"), search())
    if (is.na(pos)) {
        envir <- attach(NULL, pos=2, name=paste("pkgcode", pkg.name, sep=":"))
        pos <- 2
    } else if (search()[pos] == paste("pkgcode", pkg.name, sep=":")) {
        envir <- as.environment(pos)
    } else {
        envir <- attach(NULL, pos=pos, name=paste("pkgcode", pkg.name, sep=":"))
    }
    # Work out what R files to source
    files <- list.files(file.path(pkg.path(path, pkg.dir), "R"), all=T, pattern=pattern, full=TRUE, ignore.case=TRUE)
    if (!is.null(suffix)) {
        i <- grep(suffix, files, ignore.case=TRUE)
        if (length(files) && length(i)==0)
            warning("no files found that matched pattern \"", pattern, "\" and suffix pattern \"", suffix, "\"")
        files <- files[i]
    }
    # Omit files starting with ".#" -- these can be temporary (editor save) files
    files <- grep("^\\.#", files, invert=TRUE, value=TRUE)
    # Sort the files in the C locale
    cur.locale <- Sys.getlocale(category = "LC_COLLATE")
    Sys.setlocale(category = "LC_COLLATE", locale = "C")
    on.exit(Sys.setlocale(category = "LC_COLLATE", locale = cur.locale))
    # If we have 'Collate' in DESCRIPTION, use that to sort the files
    collate.string <- desc[[paste("collate", .Platform$OS.type, sep=".")]]
    if (is.null(collate.string))
        collate.string <- desc$collate
    if (!is.null(collate.string)) {
        # 'Collate' is space separated, possibly with quotes
        collation.order <- try(scan(textConnection(collate.string), quiet=TRUE, what="", quote="'\""))
        # Seems odd that 'Collate' is space separated while 'Depends' is comma-separated
        # So try to make the code work with both
        collation.order <- gsub("^[ \t,]+", "", collation.order)
        collation.order <- gsub("[ \t,]+$", "", collation.order)
        if (is(collation.order, "try-error")) {
            warning("could not parse COLLATE field in DESCRIPTION file: ", collate.string)
        } else {
            # Be more liberal about COLLATE than R CMD is: any files that appear
            # in COLLATE go first in the order specified, others go after
            cat("Putting source files into order specified by 'Collate' in DESCRIPTION\n")
            files.order <- order(match(basename(files), collation.order, nomatch=NA), na.last=TRUE)
            files <- files[files.order]
        }
    }
    cat("Reading ", length(files), " .R files into env at pos ", pos, ": '", search()[pos], "'\n", sep="")
    names(files) <- files
    problems <- c(problems, lapply(files,
           function(file) {
               cat("Sourcing ", file, "\n", sep="")
               try(sys.source(file, envir=envir))
               }
           ))

    # Work out what data files to load (look for .rdata,
    # .rda, case insensitive) This does NOT cover the full
    # spectrum of possible data formats -- see R-exts for
    # details.  If more formats are added here, add them to
    # man/source.pkg.Rd too.
    if (file.exists(file.path(pkg.path(path, pkg.dir), "data"))) {
        files <- list.files(file.path(pkg.path(path, pkg.dir), "data"), all=T, pattern=".*\\.rda(ta)?$", full=TRUE, ignore.case=TRUE)
        names(files) <- files
        problems <- c(problems, lapply(files,
               function(file) {
                   cat("Loading ", file, "\n", sep="")
                   res <- try(load(file, envir=envir))
                   if (is(res, "try-error"))
                       return(res)
                   else
                       return(NULL)
               }))
    }

    # Do we need to load and DLL's or SO's?
    if (dlls=="check") {
        # Try to find object files under <pkg.dir>.Rcheck and load them
        dll.dir <- gsub("\\\\", "/", file.path(pkg.path(path, paste(pkg.dir, ".Rcheck", sep="")), pkg.dir, "libs"))
        if (!file.exists(dll.dir)) {
            cat("Looking for DLL/SO files, but directory", dll.dir, "doesn't exist\n")
        } else {
            objfiles <- list.files(dll.dir, pattern=paste("*", .Platform$dynlib.ext, sep=""), ignore.case=TRUE)
            if (length(objfiles)==0) {
                cat("Looking for DLL/SO files, but did not find any", .Platform$dynlib.ext, "files in ", dll.dir, "\n", fill=TRUE)
            } else {
                loadedDLLs <- sapply(unclass(getLoadedDLLs()), "[[", "path")
                for (dll in file.path(dll.dir, objfiles)) {
                    if (is.element(dll, loadedDLLs)) {
                        cat("Attempting to unload DLL/SO", dll, "\n")
                        cat("Warning: this can be an unreliable operation on some systems\n")
                        res <- try(dyn.unload(dll))
                        if (is(res, "try-error")) {
                            warning("failed to unload", dll, ": ", res)
                            problem <- list(as.character(res))
                            names(problem) <- paste("unloading", dll)
                            problems <- c(problems, problem)
                        }
                    }
                    cat("Attempting to load DLL/SO", dll, "\n")
                    res <- try(dyn.load(dll))
                    if (is(res, "try-error")) {
                        warning("failed to load", dll, ": ", res)
                        problem <- list(as.character(res))
                        names(problem) <- paste("loading", dll)
                        problems <- c(problems, problem)
                    }
                }
            }
        }
    }
    invisible(problems[!sapply(problems, is.null)])
}