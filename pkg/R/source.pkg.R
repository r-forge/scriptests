source.pkg <- function(pkg.dir=getOption("scriptests.pkg.dir"),
                       pattern=".*", suffix="\\.R$", dlls=c("no", "check"),
                       pos=NA, all=FALSE, reset.function.envirs=TRUE,
                       path=getOption("scriptests.pkg.path", default=getwd())) {
    dlls <- match.arg(dlls)
    if (regexpr("^(/|\\\\|[a-zA-Z]:)", pkg.dir) > 0)
        pkg.dir.path <- pkg.dir
    else
        pkg.dir.path <- pkg.path(path, pkg.dir)
    if (!file.exists(pkg.dir.path))
        stop("cannot find package directory ", pkg.dir.path, " using path='", path, "'")
    if (!missing(pkg.dir))
        options("scriptests.pkg.dir"=pkg.dir)
    if (!missing(path))
        options("scriptests.pkg.path"=path)
    desc <- NULL
    if (file.exists(file.path(pkg.dir.path, "DESCRIPTION"))) {
        desc <- read.dcf(file.path(pkg.dir.path, "DESCRIPTION"))
        desc <- structure(as.list(as.character(desc[1,])), names=casefold(colnames(desc)))
    }
    pkg.name <- read.pkg.name(pkg.dir.path, pkg.dir)
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
                    cat("  Depends element '", dep, "' is already loaded\n", sep="")
                } else {
                    cat("Doing require(", dep, ") to satisfy Depends in DESCRIPTION\n", sep="")
                    if (!require(dep, character.only=TRUE, quietly=TRUE, warn.conflicts=FALSE, save=FALSE))
                        problems <- c(problems, structure("problems loading", names=paste("dependency", dep)))
                }
            }
        }
    }

    # See if we need to create a new environment on the search path
    oldpos <- match(paste("pkgcode", pkg.name, sep=":"), search())
    if (is.na(oldpos)) {
        # we do need to create a new one
        if (is.na(pos))
            pos <- 2
        envir <- attach(NULL, pos=pos, name=paste("pkgcode", pkg.name, sep=":"))
    } else {
        # we have an old one, make sure it is in the right spot
        envir <- as.environment(oldpos)
        if (is.na(pos)) {
            pos <- oldpos
        } else {
            if (pos!=oldpos) {
                detach(oldpos)
                attach(envir, pos=pos, name=paste("pkgcode", pkg.name, sep=":"))
            }
        }
    }
    # Work out which R files to source
    files <- list.files(file.path(pkg.dir.path, "R"), all.files=T, pattern=pattern, full.names=TRUE, ignore.case=TRUE)
    if (!is.null(suffix)) {
        i <- grep(suffix, files, ignore.case=TRUE)
        if (length(files) && length(i)==0)
            warning("no files found that matched pattern \"", pattern, "\" and suffix pattern \"", suffix, "\"")
        files <- files[i]
    }
    file.times <- file.info(files)
    if (!all) {
        if (exists(".file.times.old", envir=envir, inherits=FALSE)) {
            file.times.old <- get(".file.times.old", envir=envir, inherits=FALSE)
            # rely on data.frame indexing returning NA for files not in file.times.old
            touched <- file.times[files, "mtime"] > file.times.old[files, "mtime"]
            touched <- is.na(touched) | touched
            if (sum(touched))
                cat("Only reading", sum(touched), "changed .R files;", sum(!touched), "are unchanged\n")
            else
                cat("No .R files have changed;", sum(!touched), "are unchanged\n")
            files <- files[touched]
        }
    }
    # Omit files starting with ".#" -- these can be temporary (editor save) files
    files <- grep("^\\.#", files, invert=TRUE, value=TRUE)
    # Sort the files in the C locale
    cur.locale <- Sys.getlocale(category = "LC_COLLATE")
    Sys.setlocale(category = "LC_COLLATE", locale = "C")
    on.exit(Sys.setlocale(category = "LC_COLLATE", locale = cur.locale), add=TRUE)
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
    problems <- list()
    if (length(files)) {
        problems <- c(problems, lapply(files,
                                       function(file) {
                                           cat("Sourcing ", file, "\n", sep="")
                                           try(sys.source(file, envir=envir))
                                       }
                                       ))
    }
    if (all(sapply(problems, is.null)))
        assign(".file.times.old", envir=envir, value=file.times)
    if (length(files) && reset.function.envirs) {
        # Reset the environments on all functions in envir to be the global env
        for (fn in ls(envir=envir, all=TRUE)) {
            f <- get(fn, envir=envir, inherits=FALSE)
            if (is.function(f) & !identical(environment(f), globalenv())) {
                environment(f) <- globalenv()
                assign(fn, f, envir=envir)
            }
        }
    }

    # Work out what data files to load (look for .rdata,
    # .rda, case insensitive) This does NOT cover the full
    # spectrum of possible data formats -- see R-exts for
    # details.  If more formats are added here, add them to
    # man/source.pkg.Rd too.
    if (file.exists(file.path(pkg.dir.path, "data"))) {
        files <- list.files(file.path(pkg.dir.path, "data"), all.files=T, pattern=".*\\.rda(ta)?$", full.names=TRUE, ignore.case=TRUE)
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
        # Try to find object files under <pkg.dir>.Rcheck/<pkg.name> OR <pkg.name>.Rcheck/<pkg.name> and load them
        dll.dir <- NULL
        dll.dir1 <- gsub("\\\\", "/", file.path(pkg.path(path, paste(pkg.dir, ".Rcheck", sep="")), pkg.name, "libs"))
        dll.dir2 <- gsub("\\\\", "/", file.path(pkg.path(path, paste(pkg.name, ".Rcheck", sep="")), pkg.name, "libs"))
        if (file.exists(dll.dir1)) {
            if (file.exists(dll.dir2)) {
                # both exist, use the more recently modified one
                if (diff(file.info(c(dll.dir1, dll.dir2))$mtime) > 0)
                    dll.dir <- dll.dir2
                else
                    dll.dir <- dll.dir1
            } else {
                dll.dir <- dll.dir1
            }
        } else if (file.exists(dll.dir2)) {
            dll.dir <- dll.dir2
        } else {
            cat("Looking for DLL/SO files, but directories", dll.dir1, "and", dll.dir2, "don't exist", fill=TRUE)
        }
        if (!is.null(dll.dir)) {
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

pkg.path <- function(path, pkg.dir) {
    if ((i <- regexpr("$PKG", path, fixed=TRUE)) >= 1) {
        return(gsub("$PKG", pkg.dir, path, fixed=TRUE))
    } else {
        return(file.path(path, pkg.dir))
    }
}

read.pkg.name <- function(path, pkg.dir) {
    desc.path <- file.path(path, "DESCRIPTION")
    default.pkg.name <- basename(path)
    if (default.pkg.name == "pkg") {
        default.pkg.name <- dirname(basename(path))
        # if we didn't get a plausible pkg name this way, go back to "pkg"
        if ((default.pkg.name %in% c(".", "", "/", "\\")) || regexpr("^[a-zA-Z]:", default.pkg.name)>0)
            default.pkg.name <- basename(path)
    }
    # cat("  Reading", desc.path, "\n")
    if (file.exists(desc.path)) {
        pkg.name <- as.character(drop(read.dcf(desc.path, "Package")))
        if (is.na(pkg.name)) {
            warning("No 'Package' field in ", desc.path, "; using package name='", default.pkg.name, "'")
            pkg.name <- default.pkg.name
        }
    } else {
        warning("File ", desc.path, " doesn't exist; using package name='", default.pkg.name, "'")
        pkg.name <- default.pkg.name
    }
    return(pkg.name)
}
